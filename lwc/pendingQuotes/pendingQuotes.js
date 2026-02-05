import { LightningElement, wire, track } from 'lwc';
import getPendingQuotes from '@salesforce/apex/PendingQuotesController.getPendingQuotes';
import approveQuote from '@salesforce/apex/PendingQuotesController.approveQuote';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PendingQuotes extends LightningElement {
    @track rows = [];
    errorMessage = '';
    isLoading = false;

    wiredResult;

    columns = [
        { label: 'Quote Name', fieldName: 'quoteName' },
        { label: 'Opportunity', fieldName: 'opportunityName' },
        { label: 'Discount', fieldName: 'discount', type: 'number' },
        { label: 'Total Amount', fieldName: 'totalAmount', type: 'currency' },
        {
            type: 'button',
            fixedWidth: 120,
            typeAttributes: {
                label: 'Approve',
                name: 'approve',
                title: 'Approve Quote',
                variant: 'brand'
            }
        }
    ];

    @wire(getPendingQuotes)
    wiredQuotes(result) {
        this.wiredResult = result;

        if (result.data) {
            this.errorMessage = '';
            this.rows = result.data.map(q => ({
                id: q.Id,
                quoteName: q.Name,
                opportunityName: q.Opportunity.Name,
                discount: q.Discount__c,
                totalAmount: q.Total_Amount__c
            }));
        } else if (result.error) {
            this.rows = [];
            this.errorMessage = JSON.stringify(result.error);
        }
    }

    // checkeando si hay quote
    get isEmpty() {
        return !this.errorMessage && this.rows && this.rows.length === 0 && !this.isLoading;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName !== 'approve') return;

        this.isLoading = true;

        approveQuote({ quoteId: row.id })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Approved',
                        message: 'Quote approved successfully.',
                        variant: 'success'
                    })
                );

                return refreshApex(this.wiredResult);
            })
            .catch(e => {
                const msg =
                    e?.body?.message ||
                    e?.body?.pageErrors?.[0]?.message ||
                    e?.message ||
                    JSON.stringify(e);

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error approving quote',
                        message: msg,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}
