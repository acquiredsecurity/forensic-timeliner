// Utils/Discovery.cs
using ForensicTimeliner.Models;

namespace ForensicTimeliner.Utils;

public static class Discovery
{
    public static List<string> FindArtifactFiles(string inputDir, string baseDir, string artifactName)
    {
        var matches = new List<string>();

        if (!Directory.Exists(inputDir))
        {
            Console.WriteLine($"[Discovery] Input directory not found: {inputDir}");
            return matches;
        }

        if (!DiscoveryConfig.ARTIFACT_DEFINITIONS.TryGetValue(artifactName, out var artifact))
        {
            Console.WriteLine($"[Discovery] No known signature for artifact: {artifactName}");
            return matches;
        }

        if (!artifact.Enabled)
        {
            Console.WriteLine($"[Discovery] Artifact {artifactName} is disabled in configuration");
            return matches;
        }

        var csvFiles = Directory.GetFiles(inputDir, "*.csv", SearchOption.AllDirectories);

        foreach (var filePath in csvFiles)
        {
            string folderName = Path.GetFileName(Path.GetDirectoryName(filePath) ?? "");
            string fileName = Path.GetFileName(filePath);


            string normalizedFileName = StripDatePrefix(fileName);

            bool folderMatched = artifact.Discovery.StrictFolderMatch
                ? artifact.Discovery.FoldernamePatterns.Any(p => folderName.Equals(p, StringComparison.OrdinalIgnoreCase))
                : artifact.Discovery.FoldernamePatterns.Any(p => folderName.Contains(p, StringComparison.OrdinalIgnoreCase));

            bool fileMatched = artifact.Discovery.StrictFilenameMatch
                ? artifact.Discovery.FilenamePatterns.Any(p => string.Equals(normalizedFileName, p, StringComparison.OrdinalIgnoreCase))
                : artifact.Discovery.FilenamePatterns.Any(p => normalizedFileName.Contains(p, StringComparison.OrdinalIgnoreCase));

         
            if (artifact.Discovery.StrictFilenameMatch && !fileMatched)
            {
                continue; 
            }

            if (artifact.Discovery.StrictFolderMatch && !folderMatched)
            {
                continue; 
            }

            if (fileMatched && folderMatched)
            {
                matches.Add(filePath);
                continue;
            }

            if (!fileMatched && !folderMatched && artifact.Discovery.RequiredHeaders.Any())
            {
                try
                {
                    using var reader = new StreamReader(filePath);
                    string? headerLine = reader.ReadLine();
                    if (headerLine == null) continue;

                    var headers = headerLine.Split(',').Select(h => h.Trim().ToLower()).ToList();
                    var required = artifact.Discovery.RequiredHeaders.Select(h => h.ToLower()).ToList();

                    int matchedHeaders = required.Count(h => headers.Contains(h));
                    int threshold = artifact.Discovery.StrictHeaderMatch
                        ? required.Count
                        : (int)Math.Ceiling(required.Count * 0.75);

                    if (matchedHeaders >= threshold)
                    {
                        Console.WriteLine($"[Discovery] Header match fallback for {artifact.Artifact}: {Path.GetFileName(filePath)} (matched {matchedHeaders}/{required.Count})");
                        matches.Add(filePath);
                    }
                    else if (matchedHeaders >= required.Count * 0.9)
                    {
                        Console.WriteLine($"[Discovery] Skipped {Path.GetFileName(filePath)}: matched {matchedHeaders}/{required.Count} headers");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[Discovery] Failed to inspect {filePath}: {ex.Message}");
                }
            }
        }

        return matches;
    }

    private static string StripDatePrefix(string fileName)
    {

        if (fileName.Length > 16 && fileName[8] == '_' && fileName[15] == '_')
        {
            return fileName.Substring(16);
        }
        return fileName;
    }
}
