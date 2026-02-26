using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using ForensicTimeliner.Models;
using ForensicTimeliner.Utils;
using ForensicTimeliner;

namespace ForensicTimeliner.Utils
{
    public static class DateFilter
    {
        public static List<TimelineRow> FilterRowsByDate(List<TimelineRow> rows, DateTime? start, DateTime? end)
        {
            if (!start.HasValue && !end.HasValue)
            {
                // No need to modify TimelineState.RowsFilteredByDate as it's a calculated property
                TimelineState.RowCountAfterDateFilter = rows.Count;
                return rows;
            }

            var filtered = new List<TimelineRow>();
            int parseFailures = 0;
            int startFiltered = 0;
            int endFiltered = 0;

            foreach (var row in rows)
            {
                if (string.IsNullOrWhiteSpace(row.DateTime))
                    continue;

                if (!DateTime.TryParse(row.DateTime, CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var parsedDate))
                {
                    parseFailures++;
                    if (parseFailures <= 5)
                        Logger.LogError($"Failed to parse date: {row.DateTime}");
                    continue;
                }

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

                filtered.Add(row);
            }

            if (parseFailures > 0)
                Logger.LogWarning($"Date filtering had {parseFailures} parse failures");

            if (start.HasValue)
                Logger.LogInfo($"Filtered out {startFiltered} rows before {start.Value}");

            if (end.HasValue)
                Logger.LogInfo($"Filtered out {endFiltered} rows after {end.Value}");

            // Only need to set RowCountAfterDateFilter, not RowsFilteredByDate (which is calculated)
            TimelineState.RowCountAfterDateFilter = filtered.Count;
            return filtered;
        }
    }
}