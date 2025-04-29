using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.CLI;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.Nirsoft;

public class BrowsingHistoryViewParser : IArtifactParser
{
    public List<TimelineRow> Parse(string inputDir, string baseDir, ArtifactDefinition artifact, ParsedArgs args)
    {
        var rows = new List<TimelineRow>();

        Logger.PrintAndLog($"[>] - [{artifact.Artifact}] Scanning for relevant CSVs under: [{inputDir}", "SCAN");

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

                var records = csv.GetRecords<dynamic>();
                foreach (var record in records)
                {
                    var dict = (IDictionary<string, object>)record;
                    var parsedDt = dict.GetDateTime("Visit Time");
                    if (parsedDt == null) continue;

                    string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                    string url = dict.GetString("URL").Trim().ToLower();
                    string title = dict.GetString("Title");
                    string browser = dict.GetString("Web Browser");
                    string description = browser;

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
                        TimestampInfo = "Last Visited",
                        ArtifactName = "Web History",
                        Tool = artifact.Tool,
                        Description = description,
                        DataPath = url,
                        DataDetails = title,
                        User = dict.GetString("User Profile"),
                        EvidencePath = Path.GetRelativePath(baseDir, file)
                    });

                    timelineCount++;
                }

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
}
