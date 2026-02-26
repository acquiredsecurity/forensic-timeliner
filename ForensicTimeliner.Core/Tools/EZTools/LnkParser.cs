// Tools/EZTools/LnkParser.cs
using CsvHelper;
using CsvHelper.Configuration;
using ForensicTimeliner.Models;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System.Globalization;

namespace ForensicTimeliner.Tools.EZTools;

public class LnkParser : IArtifactParser
{
    private static readonly Dictionary<string, string> TimestampFields = new()
    {
        { "SourceCreated", "Source Created" },
        { "SourceModified", "Source Modified" },
        { "SourceAccessed", "Source Accessed" },
        { "TargetCreated", "Target Created" },
        { "TargetModified", "Target Modified" },
        { "TargetAccessed", "Target Accessed" },
        { "TrackerCreatedOn", "Tracker Created" }
    };

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
                var rawRecords = new List<IDictionary<string, object>>();

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
                        rawRecords.Add(dict);
                    }
                }

                foreach (var dict in rawRecords)
                {
                    foreach (var pair in TimestampFields)
                    {
                        var parsedDt = dict.GetDateTime(pair.Key);
                        if (parsedDt == null) continue;

                        string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                        string dataPath = dict.GetString("LocalPath");
                        if (string.IsNullOrWhiteSpace(dataPath))
                            dataPath = dict.GetString("TargetIDAbsolutePath");
                        if (string.IsNullOrWhiteSpace(dataPath))
                            dataPath = dict.GetString("NetworkPath");

                        string dataDetails = !string.IsNullOrWhiteSpace(dataPath)
                            ? Path.GetFileName(dataPath)
                            : dict.GetString("RelativePath");

                        string fileExt = !string.IsNullOrEmpty(dataPath)
                            ? Path.GetExtension(dataPath)?.TrimStart('.') ?? string.Empty
                            : string.Empty;

                        long fileSize = dict.GetLong("FileSize");

                        rows.Add(new TimelineRow
                        {
                            DateTime = dtStr,
                            TimestampInfo = pair.Value,
                            ArtifactName = artifact.Artifact,
                            Tool = artifact.Tool,
                            Description = artifact.Description,
                            DataDetails = dataDetails,
                            DataPath = dataPath,
                            FileExtension = fileExt,
                            FileSize = fileSize,
                            EvidencePath = Path.GetRelativePath(baseDir, file)
                        });

                        timelineCount++;
                    }
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
