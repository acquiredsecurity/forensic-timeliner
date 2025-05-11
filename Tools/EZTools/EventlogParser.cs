using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.CLI;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using System.Globalization;

namespace ForensicTimeliner.Tools.EZTools;

public class EventlogParser : IArtifactParser
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
            int parsedRows = 0;
            Logger.PrintAndLog($"[+] - [{artifact.Artifact}] Processing: {Path.GetRelativePath(baseDir, file)}", "PROCESS");

            try
            {
                List<IDictionary<string, object>> filteredRecords = new();

                using (var reader = new StreamReader(file))
                using (var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture)
                {
                    HeaderValidated = null,
                    MissingFieldFound = null
                }))
                {
                    foreach (var record in csv.GetRecords<dynamic>())
                    {
                        var dict = (IDictionary<string, object>)record;
                        if (PassesFilter(dict, artifact))
                        {
                            filteredRecords.Add(dict);
                        }
                    }
                }

                ProgressUtils.Show(file, artifact.Artifact, filteredRecords.Count, task =>
                {
                    foreach (var dict in filteredRecords)
                    {
                        var parsedDt = dict.GetDateTime("TimeCreated");
                        if (parsedDt == null) continue;

                        string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                        var row = new TimelineRow
                        {
                            DateTime = dtStr,
                            TimestampInfo = "Event Time",
                            ArtifactName = "Event Logs",
                            Tool = artifact.Tool,
                            Description = dict.GetString("MapDescription"),
                            DataDetails = dict.GetString("Channel"),
                            DataPath = BuildEventlogDataPath(dict),
                            Computer = dict.GetString("Computer"),
                            User = dict.GetString("UserName"),
                            DestinationAddress = dict.GetString("RemoteHost"),
                            EventId = dict.GetString("EventId"),
                            EvidencePath = Path.GetRelativePath(baseDir, file)
                        };

                        if (args.IncludeRawData)
                        {
                            row.RawData = dict.GetString("Payload");
                        }

                        rows.Add(row);
                        parsedRows++;
                        task.Increment(1);
                    }
                });

                Logger.PrintAndLog($"[✓] - [{artifact.Artifact}] Parsed {parsedRows} timeline rows from: {Path.GetFileName(file)}", "SUCCESS");
                LoggerSummary.TrackSummary(artifact.Tool, artifact.Artifact, parsedRows);
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
        if (artifact.IgnoreFilters)
            return true;

        if (!dict.TryGetValue("EventId", out var eventIdObj) || !int.TryParse(eventIdObj?.ToString(), out var eventId))
            return false;

        string channel = dict.GetString("Channel").Trim().ToLowerInvariant();

        // First: Check Event Channel Filters
        var eventFilters = artifact.Filters?.EventChannelFilters;
        if (eventFilters != null)
        {
            var normalized = eventFilters.ToDictionary(
                kvp => kvp.Key.Trim().ToLowerInvariant(),
                kvp => kvp.Value
            );

            if (normalized.TryGetValue(channel, out var validIds) && validIds.Contains(eventId))
                return true;
        }

        // Second: Check Provider Filters
        var providerFilters = artifact.Filters?.ProviderFilters;
        if (providerFilters != null)
        {
            string? provider =
                dict.TryGetValue("Provider", out var p1) ? p1?.ToString() :
                dict.TryGetValue("Event.System.Provider", out var p2) ? p2?.ToString() :
                null;

            if (!string.IsNullOrWhiteSpace(provider))
            {
                var normalized = providerFilters.ToDictionary(
                    kvp => kvp.Key.Trim().ToLowerInvariant(),
                    kvp => kvp.Value
                );

                if (normalized.TryGetValue(provider.Trim().ToLowerInvariant(), out var validIds) && validIds.Contains(eventId))
                    return true;
            }
        }

        // If no filters matched
        return false;
    }

    private static string BuildEventlogDataPath(IDictionary<string, object> dict)
    {
        var parts = new List<string>();

        var channel = dict.GetString("Channel");
        var eventId = dict.GetString("EventID");
        var computer = dict.GetString("Computer");

        if (!string.IsNullOrWhiteSpace(channel)) parts.Add($"Channel: {channel}");
        if (!string.IsNullOrWhiteSpace(eventId)) parts.Add($"EventID: {eventId}");
        if (!string.IsNullOrWhiteSpace(computer)) parts.Add($"Computer: {computer}");

        for (int i = 1; i <= 6; i++)
        {
            var payload = dict.GetString($"PayloadData{i}");
            if (!string.IsNullOrWhiteSpace(payload))
            {
                if (payload.Length > 10000)
                {
                    payload = payload.Substring(0, 10000) + "...[truncated]";
                }
                parts.Add(payload);
            }
        }

        var combined = string.Join(" | ", parts);

        if (!string.IsNullOrEmpty(combined) && !combined.StartsWith(" "))
        {
            combined = " " + combined;
        }

        return combined;
    }
}
