Root cause: Goal settings like kcal adjustment and macro split were not being backed up, causing users to lose these preferences upon restore.
Fix: Export and import profile settings (`ConfigDBO`) during standard JSON backup and restore, including goals (e.g. `userKcalAdjustment`, `userCarbGoalPct`, `userProteinGoalPct`, `userFatGoalPct`), unit preferences, and theme choices.
Validation: ./validate.sh
