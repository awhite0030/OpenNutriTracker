Wait, `QuickAddBottomSheet` passes `widget.day`!
Where does `widget.day` come from?
It comes from the Diary page (the day label).
If `IntakeDBO.dateTime` is ALWAYS the day label, then it is ALWAYS EXACTLY midnight!
Let's check if `IntakeDBO.dateTime` is ever `DateTime.now()`.
