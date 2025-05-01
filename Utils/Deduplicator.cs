using System.Text;
using ForensicTimeliner.Models;

namespace ForensicTimeliner.Utils
{
    public static class Deduplicator
    {
        public static List<TimelineRow> Deduplicate(List<TimelineRow> rows)
        {
            var seen = new HashSet<string>();
            var deduped = new List<TimelineRow>();

            foreach (var row in rows)
            {
                var key = string.Join("|", typeof(TimelineRow).GetProperties()
                    .Select(p => p.GetValue(row)?.ToString() ?? ""));

                if (seen.Add(key))
                {
                    deduped.Add(row);
                }
            }

            return deduped;
        }

        public static void RunPostExportDeduplication(string outputPath)
        {
            try
            {
                var rawLines = File.ReadAllLines(outputPath);
                if (rawLines.Length <= 1)
                {
                    Logger.PrintAndLog("[#] Not enough data to deduplicate.", "WARN");
                    return;
                }

                var header = rawLines[0];
                var content = rawLines.Skip(1).ToList();
                var initialCount = content.Count;
                var seen = new HashSet<string>();
                var deduped = new List<string>();

                foreach (var line in content)
                {
                    if (seen.Add(line))
                    {
                        deduped.Add(line);
                    }
                }

                int removedRows = initialCount - deduped.Count;

                // Write the actual file
                File.WriteAllLines(outputPath, new[] { header }.Concat(deduped), new UTF8Encoding(false));
                Logger.PrintAndLog($"[#] - Post-export deduplication complete: removed {removedRows} rows (final count: {deduped.Count})", "SUCCESS");
            }
            catch (Exception ex)
            {
                Logger.PrintAndLog($"[#] - Post-export deduplication failed: {ex.Message}", "ERROR");
            }
        }
    }
}