using ForensicTimeliner.CLI;
using ForensicTimeliner.Interfaces;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;

namespace ForensicTimeliner.Tools.EZTools;

public class MftParser : IArtifactParser
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
                 ForensicTimeliner.Utils.ProgressUtils.ProcessCsvWithProgress(file, artifact.Artifact, (dict, task) =>

                {
                    var parsedDt = dict.GetDateTime("Created0x10");
                    if (parsedDt == null) return;

                    string dtStr = parsedDt.Value.ToString("o").Replace("+00:00", "Z");

                    string parentPath = dict.GetString("ParentPath");
                    string fileName = dict.GetString("FileName");
                    if (string.IsNullOrWhiteSpace(fileName)) return;

                    string fullPath = Path.Combine(parentPath, fileName).Replace("\\", "/");
                    string ext = dict.GetString("Extension").ToLowerInvariant();

                    var allowedPaths = artifact.Filters?.Paths ?? new List<string>();
                    if (allowedPaths.Any() && !allowedPaths.Any(p => fullPath.Contains(p, StringComparison.OrdinalIgnoreCase)))
                        return;

                    var allowedExts = artifact.Filters?.Extensions ?? new List<string>();
                    if (allowedExts.Any() && !allowedExts.Contains(ext))
                        return;

                    rows.Add(new TimelineRow
                    {
                        DateTime = dtStr,
                        TimestampInfo = "Created",
                        ArtifactName = artifact.Artifact,
                        Tool = artifact.Tool,
                        Description = artifact.Description,
                        DataPath = fullPath,
                        DataDetails = fileName,
                        FileSize = dict.GetLong("FileSize"),
                        FileExtension = ext.TrimStart('.'),
                        EvidencePath = Path.GetRelativePath(baseDir, file)
                    });

                    parsedRows++;
                    task.Increment(1);
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
}
