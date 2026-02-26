using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Models;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using System.Globalization;
using System.Text.RegularExpressions;

namespace ForensicTimeliner.Tools.Axiom;

public class AxiomEventlogsParser : IArtifactParser
{
    public List<TimelineRow> Parse(string inputDir, string baseDir, ArtifactDefinition artifact, ParsedArgs args)
    {
        var rows = new List<TimelineRow>();

        Logger.PrintAndLog($"[>] - [{artifact.Artifact}] Scanning for relevant CSVs under: [{inputDir}]", "SCAN");

        var files = Discovery.FindArtifactFiles(inputDir, baseDir, artifact.Artifact);
        if (!files.Any())
        {
            Logger.PrintAndLog($"[!] - [{artifact.Artifact}] No matching files found in: {inputDir}", "WARN");
            return rows;
        }

        foreach (var file in files)
        {
            int timelineCount = 0;
            Logger.PrintAndLog($"[+] - [{artifact.Artifact}] Processing: {Path.GetRelativePath(baseDir, file)}", "PROCESS");

            try
            {
                using var reader = new StreamReader(file);
                using var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture)
                {
                    HeaderValidated = null,
                    MissingFieldFound = null
                });

                var filteredRecords = new List<IDictionary<string, object>>();

                foreach (var record in csv.GetRecords<dynamic>())
                {
                    var dict = (IDictionary<string, object>)record;
                    if (PassesFilter(dict, artifact))
                    {
                        filteredRecords.Add(dict);
                    }
                }

                ProgressUtils.Show(file, artifact.Artifact, filteredRecords.Count, task =>
                {
                    foreach (var dict in filteredRecords)
                    {
                        var parsedDt = dict.GetDateTime("Created Date/Time - UTC+00:00 (M/d/yyyy)");
                        if (parsedDt == null)
                            continue;

                        string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                        var (datapath, datadetails) = EnrichEventRow(dict);

                        string source = dict.GetString("Source");
                        string description = "";

                        if (!string.IsNullOrWhiteSpace(source))
                        {
                            var match = Regex.Match(source, @"\\([^\\]+\.evtx)$", RegexOptions.IgnoreCase);
                            description = match.Success ? match.Groups[1].Value.Replace(".evtx", "", StringComparison.OrdinalIgnoreCase) : dict.GetString("Provider Name");
                        }

                        var row = new TimelineRow
                        {
                            DateTime = dtStr,
                            TimestampInfo = "Event Time",
                            ArtifactName = "Event Logs",
                            Tool = artifact.Tool,
                            Description = datadetails,
                            DataDetails = description,

                            DataPath = datapath,
                            Computer = dict.GetString("Computer"),
                            EventId = dict.GetString("Event ID"),
                            EvidencePath = Path.GetRelativePath(baseDir, file)
                        };

                        if (args.IncludeRawData)
                        {
                            row.RawData = dict.GetString("Event Data");
                        }

                        rows.Add(row);
                        timelineCount++;
                        task.Increment(1);
                    }
                });

                Logger.PrintAndLog($"[✓] - [{artifact.Artifact}] Parsed {timelineCount} timeline rows from: {Path.GetFileName(file)}", "SUCCESS");
                LoggerSummary.TrackSummary(artifact.Tool, artifact.Artifact, timelineCount);
            }
            catch (Exception ex)
            {
                Logger.PrintAndLog($"[{artifact.Artifact}] Failed to parse {file}: {ex.Message}", "ERROR");
            }
        }

        return rows;
    }

    private static bool PassesFilter(IDictionary<string, object> dict, ArtifactDefinition artifact)
    {
        string provider = dict.GetString("Provider Name").Trim();
        string eventIdStr = dict.GetString("Event ID");

        if (!int.TryParse(eventIdStr, out var eventId))
            return false;

        var filters = artifact.Filters?.ProviderFilters;    // <-- Corrected from EventChannelFilters

        if (filters == null || !filters.Any())
            return false;

        if (filters.TryGetValue(provider, out var validIds))
        {
            return validIds.Contains(eventId);
        }

        return false;
    }

    private static (string datapath, string datadetails) EnrichEventRow(IDictionary<string, object> dict)
    {
        string summary = dict.GetString("Event Description Summary") ?? "";
        string eventData = dict.GetString("Event Data") ?? "";

        var extractedPairs = new List<string>();
        var lines = eventData.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);

        foreach (var line in lines)
        {
            var trimmedLine = line.Trim();

            if (string.IsNullOrWhiteSpace(trimmedLine) || trimmedLine.StartsWith("<Event xmlns", StringComparison.OrdinalIgnoreCase))
                continue;

            var xmlMatch = Regex.Match(trimmedLine, @"<Data Name=""([^""]+)"">(.*?)</Data>", RegexOptions.IgnoreCase);
            if (xmlMatch.Success)
            {
                extractedPairs.Add($"{xmlMatch.Groups[1].Value}={xmlMatch.Groups[2].Value}");
                continue;
            }

            var kvMatch = Regex.Match(trimmedLine, @"^([^:=\r\n]+?)\s*[:=]\s*(.+)$");
            if (kvMatch.Success)
            {
                extractedPairs.Add($"{kvMatch.Groups[1].Value.Trim()}={kvMatch.Groups[2].Value.Trim()}");
            }
        }

        string datapath = string.Join(" | ", extractedPairs);

        return (datapath, summary);
    }
}
