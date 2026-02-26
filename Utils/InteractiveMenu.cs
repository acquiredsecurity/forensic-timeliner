using ForensicTimeliner.CLI;
using ForensicTimeliner.Models;
using Spectre.Console;
using System.Globalization;
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

        // Tool selection
        var toolChoices = AnsiConsole.Prompt(
            new MultiSelectionPrompt<string>()
                .Title("[bold yellow]Select your tools:[/]")
                .PageSize(10)
                .InstructionsText("[grey](Press [blue]<space>[/] to toggle, [green]<enter>[/] to accept)[/]")
                .AddChoices("EZ Tools / KAPE", "Axiom", "Hayabusa", "Chainsaw", "Nirsoft", "AS Tools", "All")
        );

        bool allSelected = toolChoices.Contains("All");

        config.ProcessEZ = allSelected || toolChoices.Contains("EZ Tools / KAPE");
        config.ProcessAxiom = allSelected || toolChoices.Contains("Axiom");
        config.ProcessHayabusa = allSelected || toolChoices.Contains("Hayabusa");
        config.ProcessChainsaw = allSelected || toolChoices.Contains("Chainsaw");
        config.ProcessNirsoft = allSelected || toolChoices.Contains("Nirsoft");
        config.ProcessAS = allSelected || toolChoices.Contains("AS Tools");

        // Base directory
        config.BaseDir = AnsiConsole.Ask<string>(
            "Set the base directory that contains the CSV output to build into a timeline:",
            "C:\\triage\\hostname"
        ).Trim();

        if (!Directory.Exists(config.BaseDir))
        {
            AnsiConsole.MarkupLine($"[#] Base directory not found: {config.BaseDir}", "WARN");
            Environment.Exit(1);
        }

        if (config.ProcessEZ)
        {
            AnsiConsole.Write(new Panel(
                "MFT and EventLog filters are controlled in YAML configuration files.")
                .Border(BoxBorder.Rounded)
                .BorderStyle(Style.Parse("blue"))
                .Header("Info", Justify.Center));
        }

        // Export directory
        var exportDir = AnsiConsole.Ask<string>(
            "Where would you like to save your timeline export (directory only)?",
            Path.Combine(config.BaseDir, "timeline")
        ).Trim();

        if (!Directory.Exists(exportDir))
        {
            Directory.CreateDirectory(exportDir);
            AnsiConsole.MarkupLine($"[bold green][[+]] Created directory: {exportDir}[/]");
        }

        // Export format selection
        config.ExportFormat = AnsiConsole.Prompt(
            new SelectionPrompt<string>()
                .Title("Select export format:")
                .PageSize(5)
                .AddChoices("csv", "json", "jsonl")
        );

        // ✅ Let Program.cs handle filename + timestamp + extension
        config.OutputFile = exportDir;

        AnsiConsole.MarkupLine($"[bold green][[✓]] Timeline export directory set to:[/] [blue]{exportDir}[/]");

        // Deduplication toggle
        config.Deduplicate = AnsiConsole.Confirm("Enable deduplication?", false);

        // Date filtering
        if (AnsiConsole.Confirm("Apply date range filter?", false))
        {
            config.StartDate = PromptForValidDate("Start date (YYYY-MM-DD):");

            if (AnsiConsole.Confirm("Would you like to set an End Date?", false))
            {
                config.EndDate = PromptForValidDate("End date (YYYY-MM-DD):");
            }
        }

        AnsiConsole.MarkupLine("\n[bold green][[✓]] Interactive configuration complete.[/]");
        return config;
    }

    private static DateTime PromptForValidDate(string prompt, string prefill = null)
    {
        while (true)
        {
            string input = prefill ?? AnsiConsole.Ask<string>(prompt).Trim();
            prefill = null; // Only use prefill once

            if (DateTime.TryParseExact(input, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsedDate))
            {
                return parsedDate;
            }

            AnsiConsole.MarkupLine("[#] Invalid date format. Please enter date as YYYY-MM-DD.[/]", "ERROR");
        }
    }
}
