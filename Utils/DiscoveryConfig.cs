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

    public static void LoadFromYaml(string baseConfigDir = "config")
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
        PrintConfigsWithEnabledStatus(LoadedYamlSummary);
    }

    // Create this new method to handle displaying the enabled status
    private static void PrintConfigsWithEnabledStatus(List<(string Tool, string Artifact, string Path)> configs)
    {
        // Create a new list with the enabled status included
        var configsWithStatus = configs.Select(config =>
        {
            bool isEnabled = true; // Default to true
            if (ARTIFACT_DEFINITIONS.TryGetValue(config.Artifact, out var def))
            {
                isEnabled = def.Enabled;
            }
            return (config.Tool, config.Artifact, config.Path, isEnabled);
        }).ToList();

        // Call the updated logger method
        YamlConfigLogger.PrintLoadedConfigs(configsWithStatus);
    }

    public static void RegisterParser(string artifactName, IArtifactParser parser)
    {
        ARTIFACT_PARSERS[artifactName] = parser;
    }
}

