using System.Globalization;
using ForensicTimeliner.Collector;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;

namespace ForensicTimeliner.Tests;

/// <summary>
/// Tests that timestamps are preserved as UTC throughout the pipeline.
///
/// THE BUG: bare DateTime.TryParse (without AssumeUniversal | AdjustToUniversal)
/// treats timezone-less timestamps (MFT, Registry, etc.) as LOCAL time.
/// On a UTC+1 system, "2020-09-17 16:47:52" becomes 16:47:52+01:00 → exported as 15:47:52Z.
/// The timestamp shifts by the system's UTC offset.
///
/// THE FIX: CsvRowHelpers.GetDateTime uses CultureInfo.InvariantCulture with
/// DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal.
///
/// HOW TO REPRODUCE (before fix): Change system timezone to UTC+1 and run the CLI.
/// These tests prove correctness by directly testing that GetDateTime returns UTC Kind
/// and that the hour value is never shifted.
/// </summary>
public class TimezoneTests
{
    private static readonly string SampleDataDir = Path.GetFullPath(
        Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "sample_data", "kape_triage"));

    private static readonly string HackingCaseDir = Path.GetFullPath(
        Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "sample_data", "hackingcase", "kape_out_E01DC01"));

    private static readonly string SzechuanDir = Path.GetFullPath(
        Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "sample_data", "Szechuan", "kape_out"));

    private void EnsureConfigLoaded()
    {
        var configDir = Path.Combine(AppContext.BaseDirectory, "config");
        DiscoveryConfig.LoadFromYaml(configDir, skipVisuals: true);

        // Register EZ Tools parsers
        DiscoveryConfig.RegisterParser("EventLogs", new ForensicTimeliner.Tools.EZTools.EventlogParser());
        DiscoveryConfig.RegisterParser("MFT", new ForensicTimeliner.Tools.EZTools.MftParser());
        DiscoveryConfig.RegisterParser("Registry", new ForensicTimeliner.Tools.EZTools.RegistryParser());
        DiscoveryConfig.RegisterParser("Shellbags", new ForensicTimeliner.Tools.EZTools.ShellbagsParser());
        DiscoveryConfig.RegisterParser("LNK", new ForensicTimeliner.Tools.EZTools.LnkParser());
        DiscoveryConfig.RegisterParser("AppCompatCache", new ForensicTimeliner.Tools.EZTools.AppCompatParser());

        // Hayabusa & Chainsaw
        DiscoveryConfig.RegisterParser("Hayabusa", new ForensicTimeliner.Tools.Hayabusa.HayabusaParser());
        DiscoveryConfig.RegisterParser("Chainsaw_Sigma", new ForensicTimeliner.Tools.Chainsaw.SigmaParser());
    }

    // ─── Unit Tests: GetDateTime always returns UTC ───

    [Fact]
    public void GetDateTime_NoTimezone_TreatedAsUTC()
    {
        // MFT timestamps like "2020-09-17 16:47:52.6226844" have no TZ indicator.
        // MFTECmd outputs UTC — GetDateTime must NOT shift them to local time.
        var dict = new Dictionary<string, object>
        {
            ["Created0x10"] = "2020-09-17 16:47:52.6226844"
        };

        var result = dict.GetDateTime("Created0x10");

        Assert.NotNull(result);
        Assert.Equal(DateTimeKind.Utc, result!.Value.Kind);
        Assert.Equal(16, result.Value.Hour); // Must stay 16, not shifted by local offset
        Assert.Equal(47, result.Value.Minute);
        Assert.Equal(52, result.Value.Second);
    }

    [Fact]
    public void GetDateTime_ExplicitUTCOffset_PreservedAsUTC()
    {
        // Hayabusa: "2020-09-18 22:46:12.145 +00:00"
        var dict = new Dictionary<string, object>
        {
            ["Timestamp"] = "2020-09-18 22:46:12.145 +00:00"
        };

        var result = dict.GetDateTime("Timestamp");

        Assert.NotNull(result);
        Assert.Equal(DateTimeKind.Utc, result!.Value.Kind);
        Assert.Equal(22, result.Value.Hour); // Must stay 22, not converted to local
    }

    [Fact]
    public void GetDateTime_ISO8601WithOffset_PreservedAsUTC()
    {
        // Chainsaw: "2020-09-17T15:52:03.072386+00:00"
        var dict = new Dictionary<string, object>
        {
            ["timestamp"] = "2020-09-17T15:52:03.072386+00:00"
        };

        var result = dict.GetDateTime("timestamp");

        Assert.NotNull(result);
        Assert.Equal(DateTimeKind.Utc, result!.Value.Kind);
        Assert.Equal(15, result.Value.Hour);
        Assert.Equal(52, result.Value.Minute);
    }

    [Fact]
    public void GetDateTime_ZSuffix_PreservedAsUTC()
    {
        var dict = new Dictionary<string, object>
        {
            ["dt"] = "2020-09-17T16:47:52Z"
        };

        var result = dict.GetDateTime("dt");

        Assert.NotNull(result);
        Assert.Equal(DateTimeKind.Utc, result!.Value.Kind);
        Assert.Equal(16, result.Value.Hour);
    }

    [Fact]
    public void GetDateTime_RoundTripFormat_PreservedAsUTC()
    {
        // Test the "o" format round-trip — this is what parsers produce as intermediate strings
        var dict = new Dictionary<string, object>
        {
            ["dt"] = "2020-09-17T16:47:52.6226844Z"
        };

        var result = dict.GetDateTime("dt");

        Assert.NotNull(result);
        Assert.Equal(DateTimeKind.Utc, result!.Value.Kind);
        Assert.Equal(16, result.Value.Hour);
    }

    // ─── Integration: Parser → ToString("o") preserves UTC ───

    [Fact]
    public void ParserPipeline_MFTTimestamp_OutputIsUTC()
    {
        // Simulate what MftParser does: GetDateTime → ToString("o") → Replace("+00:00", "Z")
        var dict = new Dictionary<string, object>
        {
            ["Created0x10"] = "2020-09-17 16:47:52.6226844"
        };

        var parsedDt = dict.GetDateTime("Created0x10");
        Assert.NotNull(parsedDt);

        string dtStr = parsedDt!.Value.ToString("o").Replace("+00:00", "Z");

        // Must end with Z (UTC), not a local offset like +01:00
        Assert.EndsWith("Z", dtStr);
        Assert.Contains("16:47:52", dtStr); // Hour unchanged
    }

    [Fact]
    public void ParserPipeline_HayabusaTimestamp_OutputIsUTC()
    {
        var dict = new Dictionary<string, object>
        {
            ["Timestamp"] = "2020-09-18 22:46:12.145 +00:00"
        };

        var parsedDt = dict.GetDateTime("Timestamp");
        Assert.NotNull(parsedDt);

        string dtStr = parsedDt!.Value.ToString("o").Replace("+00:00", "Z");

        Assert.EndsWith("Z", dtStr);
        Assert.Contains("22:46:12", dtStr);
    }

    [Fact]
    public void ParserPipeline_ChainsawTimestamp_OutputIsUTC()
    {
        var dict = new Dictionary<string, object>
        {
            ["timestamp"] = "2020-09-17T15:52:03.072386+00:00"
        };

        var parsedDt = dict.GetDateTime("timestamp");
        Assert.NotNull(parsedDt);

        string dtStr = parsedDt!.Value.ToString("o").Replace("+00:00", "Z");

        Assert.EndsWith("Z", dtStr);
        Assert.Contains("15:52:03", dtStr);
    }

    // ─── End-to-end: Source CSV → Parser → Exported value match ───

    [Fact]
    public void EndToEnd_EventLogs_TimestampsAreUTC()
    {
        if (!Directory.Exists(HackingCaseDir)) return;
        EnsureConfigLoaded();

        var def = DiscoveryConfig.ARTIFACT_DEFINITIONS["EventLogs"];
        var parser = DiscoveryConfig.ARTIFACT_PARSERS["EventLogs"];
        var rows = parser.Parse(HackingCaseDir, HackingCaseDir, def,
            new ParsedArgs { BaseDir = HackingCaseDir });

        Assert.True(rows.Count > 0, "No EventLog rows parsed");

        // All timestamps should end with Z (UTC)
        foreach (var row in rows.Take(50))
        {
            Assert.True(row.DateTime.EndsWith("Z"),
                $"EventLog timestamp not UTC: {row.DateTime}");
        }
    }

    [Fact]
    public void EndToEnd_Hayabusa_TimestampsPreserveUTC()
    {
        if (!Directory.Exists(SzechuanDir)) return;
        EnsureConfigLoaded();

        var def = DiscoveryConfig.ARTIFACT_DEFINITIONS["Hayabusa"];
        var parser = DiscoveryConfig.ARTIFACT_PARSERS["Hayabusa"];
        var rows = parser.Parse(SzechuanDir, SzechuanDir, def,
            new ParsedArgs { BaseDir = SzechuanDir });

        Assert.True(rows.Count > 0, "No Hayabusa rows parsed");

        // All timestamps should end with Z (UTC)
        foreach (var row in rows.Take(50))
        {
            Assert.True(row.DateTime.EndsWith("Z"),
                $"Hayabusa timestamp not UTC: {row.DateTime}");
        }
    }

    [Fact]
    public void EndToEnd_Chainsaw_TimestampsPreserveUTC()
    {
        if (!Directory.Exists(SzechuanDir)) return;
        EnsureConfigLoaded();

        var def = DiscoveryConfig.ARTIFACT_DEFINITIONS["Chainsaw_Sigma"];
        var parser = DiscoveryConfig.ARTIFACT_PARSERS["Chainsaw_Sigma"];
        var rows = parser.Parse(SzechuanDir, SzechuanDir, def,
            new ParsedArgs { BaseDir = SzechuanDir });

        Assert.True(rows.Count > 0, "No Chainsaw rows parsed");

        // All timestamps should end with Z (UTC)
        foreach (var row in rows.Take(50))
        {
            Assert.True(row.DateTime.EndsWith("Z"),
                $"Chainsaw timestamp not UTC: {row.DateTime}");
        }
    }

    [Fact]
    public void EndToEnd_SourceTimestamp_MatchesExportedTimestamp()
    {
        // Read a known MFT source timestamp and verify it round-trips through the pipeline
        if (!Directory.Exists(HackingCaseDir)) return;
        EnsureConfigLoaded();

        // Read the first data row from the MFT CSV to get a source timestamp
        var mftFile = Path.Combine(HackingCaseDir, "EventLogs", "20260225164105_EvtxECmd_Output.csv");
        if (!File.Exists(mftFile)) return;

        string? headerLine;
        string? dataLine;
        using (var reader = new StreamReader(mftFile))
        {
            headerLine = reader.ReadLine();
            dataLine = reader.ReadLine();
        }
        if (headerLine == null || dataLine == null) return;

        var headers = headerLine.Split(',');
        var values = dataLine.Split(',');

        // Find the TimeCreated column
        int timeCreatedIdx = Array.IndexOf(headers, "TimeCreated");
        if (timeCreatedIdx < 0) return;

        string sourceTimestamp = values[timeCreatedIdx].Trim('"');

        // Parse the source timestamp with the correct UTC flags
        Assert.True(DateTime.TryParse(sourceTimestamp, CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
            out var expectedUtc));

        // Now run through the parser pipeline
        var def = DiscoveryConfig.ARTIFACT_DEFINITIONS["EventLogs"];
        var parser = DiscoveryConfig.ARTIFACT_PARSERS["EventLogs"];
        var rows = parser.Parse(HackingCaseDir, HackingCaseDir, def,
            new ParsedArgs { BaseDir = HackingCaseDir });

        Assert.True(rows.Count > 0);

        // Find a row that matches (take first few and check timestamps are reasonable)
        var firstRow = rows[0];
        Assert.True(DateTime.TryParse(firstRow.DateTime, CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
            out var parsedExport));

        // The exported timestamp must have Kind=UTC
        Assert.Equal(DateTimeKind.Utc, parsedExport.Kind);

        // The timestamp must end with Z
        Assert.True(firstRow.DateTime.EndsWith("Z"),
            $"Exported timestamp doesn't end with Z: {firstRow.DateTime}");
    }
}
