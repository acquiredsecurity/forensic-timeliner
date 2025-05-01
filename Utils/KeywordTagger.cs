using System.Text.Json;
using ForensicTimeliner.Utils;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace ForensicTimeliner.Utils;

public class KeywordConfig
{
    public List<KeywordEntry> Keywords { get; set; } = new();
}

public class KeywordEntry
{
    public string Label { get; set; } = "";
    public List<string> Keywords { get; set; } = new();
}

public static class KeywordTagger
{
    public static void Run(string yamlPath, string csvPath, List<Models.TimelineRow> _)
    {
        var config = LoadKeywords(yamlPath);
        var hits = new List<int>();

        var lines = File.ReadLines(csvPath).ToList();

        // Start from i = 1 to skip header (line 0 is header)
        for (int i = 1; i < lines.Count; i++)
        {
            string line = lines[i].ToLowerInvariant();

            foreach (var entry in config.Keywords)
            {
                foreach (var keyword in entry.Keywords)
                {
                    if (line.Contains(keyword.ToLowerInvariant()))
                    {
                        hits.Add(i); // +1 to convert to 1-based TLE line number
                        break;
                    }
                }
            }
        }

        // Write TLE session file
        var session = new Dictionary<string, List<int>>
        {
            [csvPath] = hits.Distinct().OrderBy(x => x).ToList()
        };

        var json = JsonSerializer.Serialize(new { SessionFiles = session }, new JsonSerializerOptions
        {
            WriteIndented = false
        });

        File.WriteAllText($"{csvPath}.tle_sess", json);
        Logger.LogInfo($"[✓] Tagged {hits.Count} row(s) using keyword YAML: {Path.GetFileName(yamlPath)}");
    }

    private static KeywordConfig LoadKeywords(string path)
    {
        var yaml = File.ReadAllText(path);
        var deserializer = new DeserializerBuilder()
            .WithNamingConvention(CamelCaseNamingConvention.Instance)
            .Build();

        return deserializer.Deserialize<KeywordConfig>(yaml);
    }
}
