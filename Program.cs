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


namespace ForensicTimeliner;

class Program
{
    static void Main(string[] args)
    {
        try
        {

            // Force System.Text.Json source generator to compile this context
            _ = TimelineRowJsonContext.Default.ListTimelineRow;

            // Parse arguments first
            var parsedArgs = ArgParser.Parse(args);

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

            //
            if (parsedArgs.Help)
                    {
                        HelpPrinter.Show();
                        return;
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

            var rows = CollectorManager.GetAllRows(parsedArgs);

            parsedArgs.OutputFile ??= "timeline.csv";

            string filename = Path.GetFileName(parsedArgs.OutputFile);
            string directory = Path.GetDirectoryName(parsedArgs.OutputFile) ?? Directory.GetCurrentDirectory();
            string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            string fullOutputPath = Path.Combine(directory, $"{timestamp}_{filename}");



            var outputPath = Exporter.Export(rows, fullOutputPath, parsedArgs.ExportFormat);



            if (parsedArgs.Deduplicate)
            {
                Deduplicator.RunPostExportDeduplication(outputPath);
            }

            AnsiConsole.MarkupLine($"[magenta]      Timeline written to: {outputPath}[/]");
            LoggerSummary.PrintFinalSummary();
        }
        catch (Exception ex)
        {
            Logger.LogError("[!] Fatal Error: " + ex.Message);
        }
        finally
        {
            // Add the "Press any key to exit" prompt
            AnsiConsole.MarkupLine("\n[green]✓[/] Press any key to exit...");
            Console.ReadKey(true); // true parameter hides the key press from display
        }
    }
}
