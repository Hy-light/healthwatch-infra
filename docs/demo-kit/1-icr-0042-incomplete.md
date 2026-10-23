Paste into a NEW issue using the "Infrastructure Change Request (ICR)" form.
Title: ICR-0042: Expand clinic network to Kano, Enugu and Rivers

Requesting team & contact : App team · Amaka Obi (amaka@example.com)
Environment               : prod
What needs to change?     : Add Kano, Enugu and Rivers to the clinic network so their
                            clinics can upload weekly reports. Our vendor (MedSoft Ltd)
                            also needs SSH access to the clinic subnet to install their
                            reporting agent. Please just open SSH so they can get in.
Business justification    : Three state health ministries go live on 1 November.
                            Reports must be flowing before the Governors' review.
Risk level                : Low: no user impact, easily reversed
Security impact           : (LEAVE EMPTY)
Cost impact               : (LEAVE EMPTY)
Rollback plan             : (LEAVE EMPTY)
Requested change window   : Sat 24 Oct, 11:00-12:30 WAT

-------------------------------------------------------------------------------
LIVE QUESTION TO THE CLASS: "You are the Platform team. Would you accept this ICR?"
What students should spot:
  1. No rollback plan, no cost impact, no security impact
  2. "Just open SSH" = open to the whole internet. Who exactly needs access? From what IP?
  3. Risk marked "Low" but it touches security -> it is at least Medium
-------------------------------------------------------------------------------

Then EDIT the issue with the completed fields:
Security impact : Vendor SSH restricted to MedSoft's office IP only: 203.0.113.10/32
                  (to be confirmed with the vendor)
Cost impact     : Approx +$2/month (3 storage containers). Budget raised to $100.
Rollback plan   : Revert the Pull Request and re-run the pipeline (~3 minutes).
Risk level      : Medium: limited user impact or touches security
