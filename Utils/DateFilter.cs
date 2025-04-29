// Utils/DateFilter.cs
using System.Globalization;
using ForensicTimeliner.Models;

namespace ForensicTimeliner.Utils;

public static class DateFilter
{
    public static List<TimelineRow> FilterByDateRange(List<TimelineRow> rows, DateTime? start, DateTime? end)
    {
        if (!start.HasValue && !end.HasValue)
            return rows;

        var filtered = rows.Where(row =>
        {
            if (string.IsNullOrWhiteSpace(row.DateTime)) return false;
            var parsedDate = ParseFlexibleDate(row.DateTime);
            if (!parsedDate.HasValue) return false;

            if (start.HasValue && parsedDate.Value < start.Value) return false;
            if (end.HasValue && parsedDate.Value > end.Value) return false;

            return true;
        })
        .OrderBy(r => ParseFlexibleDate(r.DateTime))
        .ToList();

        return filtered;
    }

    private static DateTime? ParseFlexibleDate(string value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;

        string[] formats = {
            "yyyy-MM-ddTHH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-ddTHH:mm:ss",
            "yyyy-MM-ddTHH:mm:ss.fffffffZ",
            "yyyy-MM-dd HH:mm:ss.fffffff",
            "MM/dd/yyyy hh:mm:ss tt",
            "dd/MM/yyyy HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd",
            "MMM dd yyyy HH:mm:ss"
        };

        foreach (var fmt in formats)
        {
            if (DateTime.TryParseExact(value.Trim(), fmt, CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal, out var dt))
            {
                return dt;
            }
        }

        return null;
    }
}