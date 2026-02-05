public with sharing class QuoteTriggerHandler {

    public static void handleAfter(List<Quote> newList, Map<Id, Quote> oldMap) {


        Set<Id> oppIds = new Set<Id>();

        for (Quote q : newList) {
            if (q.OpportunityId == null) continue;

            Boolean isApprovedNow = (q.Approval_Status__c == 'Approved');
            Boolean wasApprovedBefore = (oldMap != null && oldMap.containsKey(q.Id))
                ? (oldMap.get(q.Id).Approval_Status__c == 'Approved')
                : false;

            if (isApprovedNow && !wasApprovedBefore) {
                oppIds.add(q.OpportunityId);
            }
        }

        if (oppIds.isEmpty()) return;

        List<Quote> approvedQuotes = [
            SELECT Id, OpportunityId, Total_Amount__c, LastModifiedDate
            FROM Quote
            WHERE OpportunityId IN :oppIds
              AND Approval_Status__c = 'Approved'
            ORDER BY OpportunityId, LastModifiedDate DESC
        ];

        Map<Id, Quote> oppIdToLatestApproved = new Map<Id, Quote>();
        for (Quote q : approvedQuotes) {
            if (!oppIdToLatestApproved.containsKey(q.OpportunityId)) {
                oppIdToLatestApproved.put(q.OpportunityId, q);
            }
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Id oppId : oppIdToLatestApproved.keySet()) {
            Quote latest = oppIdToLatestApproved.get(oppId);

            oppsToUpdate.add(new Opportunity(
                Id = oppId,
                Amount = latest.Total_Amount__c
            ));
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}