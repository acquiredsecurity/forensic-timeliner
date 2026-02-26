using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace ForensicTimeliner.Utils;



public static class DiscoveryConfig
{
    public static Dictionary<string, ArtifactDefinition> ARTIFACT_DEFINITIONS = new();
    public static Dictionary<string, IArtifactParser> ARTIFACT_PARSERS = new();
    public static KeywordConfig? TAGGER_CONFIG { get; private set; }


    // Keep the existing tuple structure
    private static List<(string Tool, string Artifact, string Path)> LoadedYamlSummary = new();

    public static void LoadFromYaml(string baseConfigDir = "config", bool skipVisuals = false)
    {
        var deserializer = new DeserializerBuilder()
            .WithNamingConvention(UnderscoredNamingConvention.Instance)
            .Build();

        var yamlFiles = Directory.GetFiles(baseConfigDir, "*.yaml", SearchOption.AllDirectories);

        foreach (var file in yamlFiles)
        {
            try
            {
                var yamlText = File.ReadAllText(file);
                if (Path.GetFileName(file).Equals("keywords.yaml", StringComparison.OrdinalIgnoreCase))
                {
                    var keywordDef = deserializer.Deserialize<KeywordConfig>(yamlText);
                    TAGGER_CONFIG = keywordDef;
                    continue; // Skip artifact registration for keyword file
                }
                var definition = deserializer.Deserialize<ArtifactDefinition>(yamlText);

                if (!string.IsNullOrWhiteSpace(definition.Artifact))
                {
                    ARTIFACT_DEFINITIONS[definition.Artifact] = definition;
                    LoadedYamlSummary.Add((definition.Tool, definition.Artifact, file));
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Config] Failed to load {file}: {ex.Message}");
            }
        }

        // Display the YAML load summary table
        PrintConfigsWithEnabledStatus(LoadedYamlSummary, skipVisuals);
    }

    // Create this new method to handle displaying the enabled status
    private static void PrintConfigsWithEnabledStatus(
    List<(string Tool, string Artifact, string Path)> configs,
    bool skipVisuals = false
)
    {
        if (skipVisuals || configs.Count == 0)
            return;

        var configsWithStatus = configs.Select(config =>
        {
            bool isEnabled = true;
            if (ARTIFACT_DEFINITIONS.TryGetValue(config.Artifact, out var def))
            {
                isEnabled = def.Enabled;
            }
            return (config.Tool, config.Artifact, config.Path, isEnabled);
        }).ToList();

        YamlConfigLogger.PrintLoadedConfigs(configsWithStatus, skipVisual: skipVisuals);
    }


    public static void RegisterParser(string artifactName, IArtifactParser parser)
    {
        ARTIFACT_PARSERS[artifactName] = parser;
    }
}

