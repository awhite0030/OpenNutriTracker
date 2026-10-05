Ah! Memory constraint:
"In Dart, to accurately calculate the difference in calendar days between two local DateTime objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."
Wait, if the rule is about calculating the difference in calendar days between two local DateTime objects...
Where is this done?
Let's search for `difference` and `inDays`.
