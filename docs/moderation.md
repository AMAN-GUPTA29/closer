# Handling photo reports (app owner)

Members report a photo from the photo viewer: ⋯ → Report photo → a reason. It is hidden for them
at once (RLS and storage policy, migration `20261123000010_photo_reports.sql`). Nobody in the
group is told, and clients can't read reports.

There is no admin screen or email alert yet. **Check the queue every day** and act within 24
hours.

## See the reports

Supabase dashboard → SQL Editor:

```sql
select * from public.photo_report_queue();
```

Child-safety reports come first. To look at the photo: Storage → `photos` → open the
`storage_path` shown. Open only that file.

## Close a report

```sql
select public.resolve_photo_report('<report_id>', 'dismiss');
```

| Action | Use it when | What happens |
|---|---|---|
| `dismiss` | Nothing is wrong | Stays hidden for the reporter only; everyone else keeps it |
| `remove` | It breaks the terms | Removed for everyone; files erased by the next cleanup |
| `hold` | It may be illegal, above all anything sexual involving a child | Removed for everyone at once; files **kept** until you run `remove` |

While a report is open or held, its files aren't erased, even if someone deletes the photo, the
group or the uploader's account.

To suspend the uploader: Authentication → Users → find `uploader_id` → Ban user.

## If a child may be involved

1. Run `hold` straight away.
2. Don't download, screenshot, forward or share the photo.
3. Report it to the police or Special Juvenile Police Unit (in India this is mandatory under
   POCSO Act section 19; also cybercrime.gov.in or 1930 / 112). Give them the report id and
   storage path.
4. Run `remove` only when the police say the evidence is no longer needed.

This page is not legal advice.
