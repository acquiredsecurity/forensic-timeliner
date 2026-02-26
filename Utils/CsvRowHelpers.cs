// Utils/CsvRowHelpers.cs
using System.Globalization;

namespace ForensicTimeliner.Utils;

public static class CsvRowHelpers
{
    public static string GetString(this IDictionary<string, object> dict, string key)
    {
        return dict.TryGetValue(key, out var val) ? val?.ToString() ?? string.Empty : string.Empty;
    }

    public static long GetLong(this IDictionary<string, object> dict, string key)
    {
        return long.TryParse(GetString(dict, key), out var result) ? result : 0;
    }

    public static DateTime? GetDateTime(this IDictionary<string, object> dict, string key)
    {
        var s = GetString(dict, key);
        if (string.IsNullOrWhiteSpace(s)) return null;
        return DateTime.TryParse(s, CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
            out var dt) ? dt : null;
    }
}
