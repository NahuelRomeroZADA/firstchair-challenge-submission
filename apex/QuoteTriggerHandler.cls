public with sharing class QuoteTriggerHandler {

    public static void handleAfter(List<Quote> newList, Map<Id, Quote> oldMap) {

        // Voy a guardar acá las opportunities que tengo que tocar
        Set<Id> opportunityIdsToUpdate = new Set<Id>();

        // Recorro todas las quotes que llegaron en el trigger
        for (Quote q : newList) {

            // Si no tiene oportunidad, no puedo hacer nada
            if (q.OpportunityId == null) {
                continue;
            }

            // Me fijo si la quote está aprobada ahora
            Boolean isApprovedNow = false;
            if (q.Approval_Status__c == 'Approved') {
                isApprovedNow = true;
            }

            // Me fijo si antes estaba aprobada (con oldMap)
            Boolean wasApprovedBefore = false;
            if (oldMap != null && oldMap.containsKey(q.Id)) {
                Quote oldQuote = oldMap.get(q.Id);
                if (oldQuote.Approval_Status__c == 'Approved') {
                    wasApprovedBefore = true;
                }
            }

            // Si ahora está aprobada y antes no, significa que se aprobó recién
            if (isApprovedNow == true && wasApprovedBefore == false) {
                opportunityIdsToUpdate.add(q.OpportunityId);
            }
        }

        // Si no hay oportunidades para actualizar, salgo
        if (opportunityIdsToUpdate.size() == 0) {
            return;
        }

        // Traigo todas las quotes aprobadas de esas opportunities, ordenadas por la más nueva primero
        List<Quote> approvedQuotes = [
            SELECT OpportunityId, Total_Amount__c, LastModifiedDate
            FROM Quote
            WHERE OpportunityId IN :opportunityIdsToUpdate
            AND Approval_Status__c = 'Approved'
            ORDER BY OpportunityId, LastModifiedDate DESC
        ];

        // En este mapa voy a guardar el opp ID y la quote aprobada más nueva por cada opportunity
        Map<Id, Quote> latestApprovedQuoteByOppId = new Map<Id, Quote>();

        // Como viene ordenado DESC, la primera que vea por Opportunity es la más nueva
        for (Quote q : approvedQuotes) {
            if (latestApprovedQuoteByOppId.containsKey(q.OpportunityId) == false) {
                latestApprovedQuoteByOppId.put(q.OpportunityId, q);
            }
        }

        // Armo la lista de opportunities para actualizar
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Id oppId : latestApprovedQuoteByOppId.keySet()) {

            Quote latestQuote = latestApprovedQuoteByOppId.get(oppId);

            Opportunity opp = new Opportunity();
            opp.Id = oppId;

            // Copio el total de la quote al amount de la opp
            opp.Amount = latestQuote.Total_Amount__c;

            opportunitiesToUpdate.add(opp);
        }

        // Si tengo algo, actualizo
        if (opportunitiesToUpdate.size() > 0) {
            update opportunitiesToUpdate;
        }
    }
}
