using ForensicTimeliner.CLI;
using Spectre.Console;
using System.Linq;

namespace ForensicTimeliner.Interactive;

public static class InteractiveMenu
{
    public static ParsedArgs Run()
    {
        var config = new ParsedArgs();

        AnsiConsole.Write(
            new Panel("Launching interactive configuration...")
                .Border(BoxBorder.Rounded)
                .Header("Interactive Mode", Justify.Center)
                .BorderStyle(Style.Parse("magenta"))
        );

        var toolChoices = AnsiConsole.Prompt(
            new MultiSelectionPrompt<string>()
                .Title("[bold yellow]Select your tools:[/]")
                .PageSize(10)
                .InstructionsText("[grey](Press [blue]<space>[/] to toggle, [green]<enter>[/] to accept)[/]")
                .AddChoices("EZ Tools / KAPE", "Hayabusa", "Chainsaw", "Nirsoft", "All")
        );

        // If user selects "All", clear previous and force all tools enabled
        bool allSelected = toolChoices.Contains("All");

        config.ProcessEZ = allSelected || toolChoices.Contains("EZ Tools / KAPE");
        config.ProcessHayabusa = allSelected || toolChoices.Contains("Hayabusa");
        config.ProcessChainsaw = allSelected || toolChoices.Contains("Chainsaw");
        config.ProcessNirsoft = allSelected || toolChoices.Contains("Nirsoft");

        config.BaseDir = AnsiConsole.Ask<string>("Set base directory for your CSV output from a single host:", "C:\\triage\\hostname");

        if (config.ProcessEZ)
        {
            AnsiConsole.Write(new Panel(
                "MFT and EventLog filters are controlled in YAML configuration files.")
                .Border(BoxBorder.Rounded)
                .BorderStyle(Style.Parse("blue"))
                .Header("Info", Justify.Center));
        }

        var outputFile = Path.Combine(config.BaseDir, "timeline", "forensic_timeliner.csv");
        config.OutputFile = AnsiConsole.Ask("Where would you like to save your unified Forensic Timeline?", outputFile);
        var extension = config.ExportFormat == "json" ? ".json" : ".csv";

        if (!Path.HasExtension(config.OutputFile))
        {
            config.OutputFile += extension;
        }

        config.ExportFormat = AnsiConsole.Prompt(
            new SelectionPrompt<string>()
                .Title("Select export format:")
                .PageSize(3)
                .AddChoices("csv", "json")
        );

        config.Deduplicate = AnsiConsole.Confirm("Enable deduplication?", false);

        if (AnsiConsole.Confirm("Apply date range filter?", false))
        {
            var start = AnsiConsole.Ask<string>("Start date (YYYY-MM-DD):");
            var end = AnsiConsole.Ask<string>("End date (YYYY-MM-DD):");

            if (DateTime.TryParse(start, out var startDate))
                config.StartDate = startDate;

            if (DateTime.TryParse(end, out var endDate))
                config.EndDate = endDate;
        }

        AnsiConsole.MarkupLine("\n[bold green][[✓]] Interactive configuration complete.[/]");
        return config;
    }
}
