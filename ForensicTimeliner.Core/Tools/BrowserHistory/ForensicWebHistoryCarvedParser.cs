using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.BrowserHistory;

/// <summary>
/// Parser for forensic-webhistory carved (deleted/recovered) CSV output.
/// CSV format has 6 columns:
/// URL, Title, Visit Time, Browser Hint, Recovery Source, Source File
///
/// Only rows with a valid timestamp are included in the timeline.
/// Entries are marked as "Web History (Recovered)" to distinguish from live browser history.
/// </summary>
public class ForensicWebHistoryCarvedParser : IArtifactParser
{
    public List<TimelineRow> Parse(string inputDir, string baseDir, ArtifactDefinition artifact, ParsedArgs args)
    {
        var rows = new List<TimelineRow>();

        Logger.PrintAndLog($"[>] - [{artifact.Artifact}] Scanning for carved browser history CSVs under: [{inputDir}]", "SCAN");

        var files = Discovery.FindArtifactFiles(inputDir, baseDir, artifact.Artifact);
        if (!files.Any())
        {
            Logger.PrintAndLog($"[!] - [{artifact.Artifact}] No matching files found in: {inputDir}", "WARN");
            return rows;
        }

        foreach (var file in files)
        {
            int timelineCount = 0;
            int skippedNoTimestamp = 0;

            // Only process files with the carved CSV header (must have "Recovery Source")
            try
            {
                using var headerReader = new StreamReader(file);
                var headerLine = headerReader.ReadLine();
                if (headerLine != null && !headerLine.Contains("Recovery Source", StringComparison.OrdinalIgnoreCase))
                    continue;
            }
            catch { continue; }

            Logger.PrintAndLog($"[+] - [{artifact.Artifact}] Processing: {Path.GetRelativePath(baseDir, file)}", "PROCESS");

            try
            {
                using var reader = new StreamReader(file);
                using var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture)
                {
                    HeaderValidated = null,
                    MissingFieldFound = null
                });

                var records = csv.GetRecords<dynamic>();
                foreach (var record in records)
                {
                    var dict = (IDictionary<string, object>)record;
                    var parsedDt = dict.GetDateTime("Visit Time");
                    if (parsedDt == null)
                    {
                        skippedNoTimestamp++;
                        continue;
                    }

                    string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                    string url = dict.GetString("URL").Trim().ToLower();
                    if (string.IsNullOrWhiteSpace(url)) continue;

                    string title = dict.GetString("Title");
                    string browser = dict.GetString("Browser Hint");
                    string recoverySource = dict.GetString("Recovery Source");
                    string sourceFile = dict.GetString("Source File");

                    // Build description: browser + recovery method + activity detection
                    string description = $"{browser} (Deleted — {recoverySource})";

                    // Detect activity type from URL patterns
                    if (url.StartsWith("file:///"))
                        description += " + File Open Access";
                    else if (url.Contains("search") || url.Contains("query") || url.Contains("q=") || url.Contains("p=") ||
                             url.Contains("find") || url.Contains("lookup") || url.Contains("google.com/search") ||
                             url.Contains("bing.com/search") || url.Contains("duckduckgo.com/?q=") ||
                             url.Contains("yahoo.com/search"))
                        description += " + Search";
                    else if (url.Contains("download") || url.Contains(".exe") || url.Contains(".zip") ||
                             url.Contains(".rar") || url.Contains(".7z") || url.Contains(".msi") ||
                             url.Contains(".iso") || url.Contains(".pdf") || url.Contains(".dll") ||
                             url.Contains("/downloads/"))
                        description += " + Download";

                    rows.Add(new TimelineRow
                    {
                        DateTime = dtStr,
                        TimestampInfo = "Last Visited (Recovered)",
                        ArtifactName = "Web History (Recovered)",
                        Tool = artifact.Tool,
                        Description = description,
                        DataPath = url,
                        DataDetails = title,
                        User = "",
                        Count = "",
                        NaturalLanguage = dict.GetString("NaturalLanguage"),
                        EvidencePath = Path.GetRelativePath(baseDir, file),
                        RawData = System.Text.Json.JsonSerializer.Serialize(
                            dict.ToDictionary(kvp => kvp.Key, kvp => kvp.Value?.ToString() ?? ""))
                    });

                    timelineCount++;
                }

                Logger.PrintAndLog($"[✓] - [{artifact.Artifact}] Parsed {timelineCount} recovered timeline rows from: {Path.GetFileName(file)} (skipped {skippedNoTimestamp} without timestamps)", "SUCCESS");
                LoggerSummary.TrackSummary(artifact.Tool, artifact.Artifact, timelineCount);
            }
            catch (Exception ex)
            {
                Logger.PrintAndLog($"[{artifact.Artifact}] Failed to parse {file}: {ex.Message}", "ERROR");
            }
        }

        return rows;
    }
}
