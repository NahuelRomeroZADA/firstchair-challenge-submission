The solution implements a Quote approval process using Flow, Apex and LWC.
A record-triggered flow automatically marks Quotes with a discount greater than or equal to
15% as Pending approval and sends an email alert to the assigned manager, in this case Sally Jones. The manager can review and approve pending Quotes from the Pending Quotes Component displayed on the home page.

When the most recent Quote is approved, an apex trigger updates the related Opportunity Amount using the Quotes’s Total_Amount__c, ensuring that only the most recently approved Quote determines the final Opportunity value. 

The solution includes unit test with over 80% coverage following salesforce governor limits, data integrity and scalability.
