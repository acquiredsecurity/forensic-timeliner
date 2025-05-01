using ForensicTimeliner.CLI;
using ForensicTimeliner.Collector;
using ForensicTimeliner.Interactive;
using ForensicTimeliner.Tools.Axiom;
using ForensicTimeliner.Tools.Chainsaw;
using ForensicTimeliner.Tools.EZTools;
using ForensicTimeliner.Tools.Hayabusa;
using ForensicTimeliner.Tools.Nirsoft;
using ForensicTimeliner.Utils;
using Spectre.Console;
using System;
using System.Globalization;
using System.Text.Json;


namespace ForensicTimeliner;

class Program
{
    static void Main(string[] args)
    {
        if (args.Length == 0)
        {
            // If EXE was double-clicked or no args supplied, default to interactive mode
            args = new[] { "--Interactive" };
        }
        try
        {
            // Force System.Text.Json source generator to compile this context
            _ = TimelineRowJsonContext.Default.ListTimelineRow;

            // Parse arguments first
            var parsedArgs = ArgParser.Parse(args);
            parsedArgs.ExportFormat = string.IsNullOrWhiteSpace(parsedArgs.ExportFormat)
                ? "csv"
                : parsedArgs.ExportFormat.Trim().ToLowerInvariant();

            if (!new[] { "csv", "json", "jsonl" }.Contains(parsedArgs.ExportFormat))
            {
                AnsiConsole.MarkupLine($"Invalid export format: {parsedArgs.ExportFormat}", "ERROR");
                AnsiConsole.MarkupLine("[yellow]Valid options: csv, json, jsonl[/]");
                Environment.Exit(1);
            }

            // Handle --Help (-h, etc.) immediately after parsing
            if (parsedArgs.Help)
            {
                HelpPrinter.Show();
                return;
            }

            // Handle --Interactive (-i, etc.)
            if (parsedArgs.Interactive)
            {
                parsedArgs = InteractiveMenu.Run();
            }

            // Check if help was selected in interactive mode
            if (parsedArgs.Help)
            {
                HelpPrinter.Show();
                return;
            }

            // Check if config folder exists before loading YAMLs
            var configFolderPath = Path.Combine(AppContext.BaseDirectory, "config");

            if (!Directory.Exists(configFolderPath))
            {
                AnsiConsole.MarkupLine("Fatal Error: Missing required 'config' folder at:" + configFolderPath + "", "WARN");
                Environment.Exit(1);
            }

            // Load default discovery signatures
            DiscoveryConfig.LoadFromYaml();

            // Register YAML parsers
            // Axiom
            DiscoveryConfig.RegisterParser("Axiom_ActivityTimeline", new AxiomActivityTimelineParser());
            DiscoveryConfig.RegisterParser("Axiom_Amcache", new AxiomAmcacheParser());
            DiscoveryConfig.RegisterParser("Axiom_AppCompat", new AxiomAppCompatParser());
            DiscoveryConfig.RegisterParser("Axiom_AutoRuns", new AxiomAutoRunsParser());
            DiscoveryConfig.RegisterParser("Axiom_ChromeHistory", new AxiomChromeHistoryParser());
            DiscoveryConfig.RegisterParser("Axiom_Edge", new AxiomEdgeParser());
            DiscoveryConfig.RegisterParser("Axiom_EventLogs", new AxiomEventlogsParser());
            DiscoveryConfig.RegisterParser("Axiom_Firefox", new AxiomFirefoxParser());
            DiscoveryConfig.RegisterParser("Axiom_IEHistory", new AxiomIEHistoryParser());
            DiscoveryConfig.RegisterParser("Axiom_JumpLists", new AxiomJumpListsParser());
            DiscoveryConfig.RegisterParser("Axiom_LNK", new AxiomLnkParser());
            DiscoveryConfig.RegisterParser("Axiom_MRUFolderAccess", new AxiomMruFolderAccessParser());
            DiscoveryConfig.RegisterParser("Axiom_MRUOpenSaved", new AxiomMruOpenSavedParser());
            DiscoveryConfig.RegisterParser("Axiom_MRURecent", new AxiomMruRecentParser());
            DiscoveryConfig.RegisterParser("Axiom_Opera", new AxiomOperaParser());
            DiscoveryConfig.RegisterParser("Axiom_Prefetch", new AxiomPrefetchParser());
            DiscoveryConfig.RegisterParser("Axiom_RecycleBin", new AxiomRecycleBinParser());
            DiscoveryConfig.RegisterParser("Axiom_Shellbags", new AxiomShellbagsParser());
            DiscoveryConfig.RegisterParser("Axiom_UserAssist", new AxiomUserAssistParser());

            // EZ Tools
            DiscoveryConfig.RegisterParser("ActivityTimeline", new ActivityTimelineParser());
            DiscoveryConfig.RegisterParser("Amcache", new AmcacheParser());
            DiscoveryConfig.RegisterParser("AppCompatCache", new AppCompatParser());
            DiscoveryConfig.RegisterParser("FileDeletion", new DeletedParser());
            DiscoveryConfig.RegisterParser("EventLogs", new EventlogParser());
            DiscoveryConfig.RegisterParser("Jumplists", new JumplistsParser());
            DiscoveryConfig.RegisterParser("LNK", new LnkParser());
            DiscoveryConfig.RegisterParser("MFT", new MftParser());
            DiscoveryConfig.RegisterParser("Prefetch", new PrefetchParser());
            DiscoveryConfig.RegisterParser("Registry", new RegistryParser());
            DiscoveryConfig.RegisterParser("Shellbags", new ShellbagsParser());

            // Hayabusa
            DiscoveryConfig.RegisterParser("Hayabusa", new HayabusaParser());

            // Chainsaw
            DiscoveryConfig.RegisterParser("Chainsaw_AccountTampering", new AccountTamperingParser());
            DiscoveryConfig.RegisterParser("Chainsaw_Antivirus", new AntivirusParser());
            DiscoveryConfig.RegisterParser("Chainsaw_Applocker", new ApplockerParser());
            DiscoveryConfig.RegisterParser("Chainsaw_CredentialAccess", new CredentialAccessParser());
            DiscoveryConfig.RegisterParser("Chainsaw_DefenseEvasion", new DefenseEvasionParser());
            DiscoveryConfig.RegisterParser("Chainsaw_IndicatorRemoval", new IndicatorRemovalParser());
            DiscoveryConfig.RegisterParser("Chainsaw_LateralMovement", new LateralMovementParser());
            DiscoveryConfig.RegisterParser("Chainsaw_LogTampering", new LogTamperingParser());
            DiscoveryConfig.RegisterParser("Chainsaw_LoginAttacks", new LoginAttacksParser());
            DiscoveryConfig.RegisterParser("Chainsaw_MicrosoftRasVpnEvents", new MicrosoftRasVpnEventsParser());
            DiscoveryConfig.RegisterParser("Chainsaw_MicrosoftRdsEvents", new MicrosoftRdsEventsParser());
            DiscoveryConfig.RegisterParser("Chainsaw_Persistence", new PersistenceParser());
            DiscoveryConfig.RegisterParser("Chainsaw_Powershell", new PowershellParser());
            DiscoveryConfig.RegisterParser("Chainsaw_RdpEvents", new RdpEventsParser());
            DiscoveryConfig.RegisterParser("Chainsaw_ServiceInstallation", new ServiceInstallationParser());
            DiscoveryConfig.RegisterParser("Chainsaw_ServiceTampering", new ServiceTamperingParser());
            DiscoveryConfig.RegisterParser("Chainsaw_Sigma", new SigmaParser());
            DiscoveryConfig.RegisterParser("Chainsaw_Mft", new ChainsawMftParser());

            // Nirsoft
            DiscoveryConfig.RegisterParser("NirsoftBrowsingHistory", new BrowsingHistoryViewParser());

            // Print banner unless --NoBanner is set
            if (!parsedArgs.NoBanner)
            {
                Banner.Print();
            }

            // Get all rows first (no date filtering in CollectorManager)
            var rows = CollectorManager.GetAllRows(parsedArgs);
            AnsiConsole.MarkupLine($"[green]✓[/] Collected [cyan]{rows.Count:N0}[/] total rows from all artifacts");
            TimelineState.RowCountCollected = rows.Count;


            if (parsedArgs.StartDate.HasValue || parsedArgs.EndDate.HasValue)
            {
                string dateRangeText = "";
                if (parsedArgs.StartDate.HasValue && parsedArgs.EndDate.HasValue)
                {
                    dateRangeText = $"between [cyan]{parsedArgs.StartDate:yyyy-MM-dd}[/] and [cyan]{parsedArgs.EndDate:yyyy-MM-dd}[/]";
                }
                else if (parsedArgs.StartDate.HasValue)
                {
                    dateRangeText = $"after [cyan]{parsedArgs.StartDate:yyyy-MM-dd}[/]";
                }
                else
                {
                    dateRangeText = $"before [cyan]{parsedArgs.EndDate:yyyy-MM-dd}[/]";
                }

                AnsiConsole.MarkupLine($"[yellow]>[/] Filtering timeline {dateRangeText}");
                int beforeCount = rows.Count;

                rows = FilterRowsByDate(rows, parsedArgs.StartDate, parsedArgs.EndDate);
                AnsiConsole.MarkupLine($"[green]✓[/] Kept [cyan]{rows.Count:N0}[/] rows after date filtering ([red]-{beforeCount - rows.Count:N0}[/] rows removed)");
                TimelineState.RowCountAfterDateFilter = rows.Count;

            }

            parsedArgs.OutputFile ??= "timeline.csv";

            // Check if the OutputFile is a directory or a file path
            bool isDirectory = Directory.Exists(parsedArgs.OutputFile) ||
                               (!Path.HasExtension(parsedArgs.OutputFile) && !File.Exists(parsedArgs.OutputFile));

            string directory, filename;
            string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");

            // Make sure we have the correct extension based on the export format
            string extension = parsedArgs.ExportFormat.ToLower() switch
            {
                "json" => ".json",
                "jsonl" => ".jsonl",
                _ => ".csv"  // Default to CSV
            };

            if (isDirectory)
            {
                // If it's a directory, use a default filename
                directory = parsedArgs.OutputFile;
                filename = $"ForensicTimeliner{extension}";
            }
            else
            {
                // Otherwise, extract filename and directory
                filename = Path.GetFileName(parsedArgs.OutputFile);
                directory = Path.GetDirectoryName(parsedArgs.OutputFile) ?? Directory.GetCurrentDirectory();

                // If filename doesn't have the right extension, add it
                if (!Path.HasExtension(filename) ||
                    !Path.GetExtension(filename).Equals(extension, StringComparison.OrdinalIgnoreCase))
                {
                    // Remove any existing extension and add the correct one
                    filename = Path.GetFileNameWithoutExtension(filename) + extension;
                }
            }

            string fullOutputPath = Path.Combine(directory, $"{timestamp}_{filename}");

            // Ensure directory exists
            if (!Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            // Export with improved handling for empty results
            string outputPath = "";
            try
            {


                // Special case for 0 rows
                if (rows.Count == 0)
                {
                    Logger.LogInfo("No rows to export - creating empty file with headers");
                    try
                    {
                        // Create an empty file with headers
                        if (parsedArgs.ExportFormat.ToLower() == "csv")
                        {
                            // Create CSV with headers only
                            string headers = "DateTime,TimestampInfo,ArtifactName,Tool,Description,DataDetails,DataPath,FileExtension,EventId,User,Computer,FileSize,IPAddress,SourceAddress,DestinationAddress,SHA1,Count,EvidencePath,RawData";
                            File.WriteAllText(fullOutputPath, headers);
                        }
                        else if (parsedArgs.ExportFormat.ToLower() == "json")
                        {
                            // Empty JSON array
                            File.WriteAllText(fullOutputPath, "[]");
                        }
                        else if (parsedArgs.ExportFormat.ToLower() == "jsonl")
                        {
                            // Empty file is fine for JSONL
                            File.WriteAllText(fullOutputPath, "");
                        }

                        outputPath = fullOutputPath;
                        Logger.LogInfo($"Created empty file with headers: {outputPath}");
                    }
                    catch (Exception ex)
                    {
                        Logger.LogError($"Failed to create empty file: {ex.Message}");
                        AnsiConsole.MarkupLine($"[red]Failed to create empty file: {ex.Message}[/]");
                        Environment.Exit(1);
                    }
                }
                else
                {
                    // Try the actual export for non-empty rows
                    outputPath = Exporter.Export(rows, fullOutputPath, parsedArgs.ExportFormat);
                }

                if (!File.Exists(outputPath))
                {
                    Logger.LogError($"Export completed but file does not exist: {outputPath}");
                    AnsiConsole.MarkupLine($"[red]Export failed — file was not created: {outputPath}[/]");
                    Environment.Exit(1);
                }
            }
            catch (Exception ex)
            {
                Logger.LogError($"Export exception: {ex.Message}");
                Logger.LogError($"Exception details: {ex}");
                AnsiConsole.MarkupLine($"[red]Export failed with exception: {ex.Message}[/]");
                Environment.Exit(1);
            }

            if (parsedArgs.Deduplicate)
            {
                Deduplicator.RunPostExportDeduplication(outputPath);

                try
                {
                    if (parsedArgs.ExportFormat == "csv")
                    {
                        TimelineState.RowCountAfterDedup = File.ReadLines(outputPath).Count() - 1;
                    }
                    else if (parsedArgs.ExportFormat == "jsonl")
                    {
                        TimelineState.RowCountAfterDedup = File.ReadLines(outputPath).Count();
                    }
                    else if (parsedArgs.ExportFormat == "json")
                    {
                        var jsonText = File.ReadAllText(outputPath);
                        var parsed = JsonSerializer.Deserialize<List<Models.TimelineRow>>(jsonText, new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });

                        TimelineState.RowCountAfterDedup = parsed?.Count ?? 0;
                    }
                }
                catch (Exception ex)
                {
                    Logger.LogWarning($"Failed to determine final row count after deduplication: {ex.Message}");
                    TimelineState.RowCountAfterDedup = 0;
                }
            }
            else
            {
                TimelineState.RowCountAfterDedup = rows.Count;
            }
            // Run keyword tagger only if export format is CSV and tagging is enabled
            if (parsedArgs.EnableTagger && parsedArgs.ExportFormat == "csv")
            {
                string taggerPath = Path.Combine("config", "keywords", "keywords.yaml");
                if (File.Exists(taggerPath))
                {
                    // Make sure we're tagging based on the exact final exported list
                    KeywordTagger.Run(taggerPath, outputPath, rows);
                }
                else
                {
                    Logger.LogWarning($"Keyword tagging is enabled, but YAML not found at: {taggerPath}");
                }
            }

            AnsiConsole.MarkupLine($"[magenta]      Timeline written to: {outputPath}[/]");
            LoggerSummary.PrintFinalSummary();
        }
        catch (Exception ex)
        {
            try
            {
                Logger.LogError("Fatal Error: " + ex.ToString());
            }
            catch
            {
                Console.WriteLine("Fatal Error: " + ex.ToString());
            }
        }
        finally
        {
            // Add the "Press any key to exit" prompt
            AnsiConsole.MarkupLine("Press any key to exit...");
            Console.ReadKey(true); // true parameter hides the key press from display
        }
    }

    // New date filtering method that replaces DateFilter.cs
    private static List<Models.TimelineRow> FilterRowsByDate(List<Models.TimelineRow> rows, DateTime? start, DateTime? end)
    {
        if (!start.HasValue && !end.HasValue)
            return rows;

        var filtered = new List<Models.TimelineRow>();
        int parseFailures = 0;
        int startFiltered = 0;
        int endFiltered = 0;

        foreach (var row in rows)
        {
            if (string.IsNullOrWhiteSpace(row.DateTime))
                continue;

            DateTime parsedDate;
            bool success = DateTime.TryParse(row.DateTime, CultureInfo.InvariantCulture,
                                          DateTimeStyles.None, out parsedDate);

            if (!success)
            {
                parseFailures++;
                if (parseFailures <= 5) // Only log the first few failures
                {
                    Logger.LogError($"Failed to parse date: {row.DateTime}");
                }
                continue;
            }

            // Apply date range filter
            if (start.HasValue && parsedDate < start.Value)
            {
                startFiltered++;
                continue;
            }

            if (end.HasValue && parsedDate > end.Value)
            {
                endFiltered++;
                continue;
            }

            // Row passed all filters
            filtered.Add(row);
        }

        if (parseFailures > 0)
        {
            Logger.LogWarning($"Date filtering had {parseFailures} parse failures");
        }

        if (start.HasValue)
        {
            Logger.LogInfo($"Filtered out {startFiltered} rows before {start.Value}");
        }

        if (end.HasValue)
        {
            Logger.LogInfo($"Filtered out {endFiltered} rows after {end.Value}");
        }

        return filtered;
    }
}