using Spectre.Console;
using CsvHelper;
using CsvHelper.Configuration;
using System.Globalization;

namespace ForensicTimeliner.Utils;

public static class ProgressUtils
{
    public static void Show(string filePath, string artifactName, int totalRows, Action<ProgressTask> callback)
    {
        AnsiConsole.Progress()
            .AutoClear(true)
            .HideCompleted(false)
            .Columns(
                new TaskDescriptionColumn(),
                new ProgressBarColumn(),
                new PercentageColumn(),
                new ElapsedTimeColumn(),
                new RemainingTimeColumn())
            .Start(ctx =>
            {
                var task = ctx.AddTask($"[green]{artifactName}[/] → {Path.GetFileName(filePath)}", maxValue: totalRows);
                callback(task);
            });
    }

    public static void ProcessCsvWithProgress(string filePath, string artifactName, Action<IDictionary<string, object>, ProgressTask> rowCallback)
    {
        using var reader = new StreamReader(filePath);
        using var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            HeaderValidated = null,
            MissingFieldFound = null
        });

        var records = csv.GetRecords<dynamic>().ToList();
        var total = records.Count;

        AnsiConsole.Progress()
            .AutoClear(true)
            .HideCompleted(false)
            .Columns(
                new TaskDescriptionColumn(),
                new ProgressBarColumn(),
                new PercentageColumn(),
                new ElapsedTimeColumn(),
                new RemainingTimeColumn())
            .Start(ctx =>
            {
                var task = ctx.AddTask($"[green]{artifactName}[/] → {Path.GetFileName(filePath)}", maxValue: total);

                foreach (var record in records)
                {
                    var dict = (IDictionary<string, object>)record;
                    rowCallback(dict, task);
                }
            });
    }
}
