import { LightningElement, wire, track } from 'lwc';
import getPendingQuotes from '@salesforce/apex/PendingQuotesController.getPendingQuotes';
import approveQuote from '@salesforce/apex/PendingQuotesController.approveQuote';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PendingQuotes extends LightningElement {
    // Esto es lo que mostramos en la tabla (datatables)
    @track rows = [];

    // Si falla algo, guardamos acá el error para mostrarlo
    errorMessage = '';

    // Para deshabilitar cosas / mostrar spinner
    isLoading = false;

    // Acá guardamos el "resultado del wire" para poder hacer refreshApex después
    wiredResult;

    // Columnas de la tabla 
    columns = [
        { label: 'Quote Name', fieldName: 'quoteName' },
        { label: 'Opportunity', fieldName: 'opportunityName' },
        { label: 'Discount', fieldName: 'discount', type: 'number' },
        { label: 'Total Amount', fieldName: 'totalAmount', type: 'currency' },
        {
            // Este es el botón que aparece en cada fila
            type: 'button',
            fixedWidth: 120,
            typeAttributes: {
                label: 'Approve',
                name: 'approve',      // esto es la "acción" 
                title: 'Approve Quote',
                variant: 'brand'
            }
        }
    ];

    // 1) Wire: trae las quotes pendientes desde Apex
    @wire(getPendingQuotes)
    wiredQuotes(result) {
        // guardo esto para poder actualizarlo después con refreshApex
        this.wiredResult = result;

        // Si trae data, armo las filas
        if (result.data) {
            this.errorMessage = '';

            // Mapeo lo que trae Apex a un formato simple para la tabla
            // (o sea, no uso el objeto Quote entero, solo lo que me interesa mostrar)
            this.rows = result.data.map((q) => {
                return {
                    id: q.Id,
                    quoteName: q.Name,
                    opportunityName: q.Opportunity.Name,
                    discount: q.Discount__c,
                    totalAmount: q.Total_Amount__c
                };
            });
        }

        // Si hubo error, limpio la tabla y guardo el error
        if (result.error) {
            this.rows = [];
            this.errorMessage = JSON.stringify(result.error);
        }
    }

    // Esto sirve para mostrar un mensaje tipo "no hay nada" cuando no hay data y tampoco hay error
    
    get isEmpty() {
        if (this.errorMessage) return false;
        if (this.isLoading) return false;
        if (!this.rows) return true;
        return this.rows.length === 0;
    }

    // 2) Cuando apretás el botón "Approve" en una fila, cae acá
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const rowData = event.detail.row;

        // Si no es el botón approve, me voy (por si en el futuro hay más acciones)
        if (actionName !== 'approve') {
            return;
        }

        // Prendo loading para bloquear UI / mostrar spinner
        this.isLoading = true;

        // Llamo a Apex para aprobar la quote
        approveQuote({ quoteId: rowData.id })
            .then(() => {
                // Si salió bien, muestro toast verde
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Approved',
                        message: 'Quote approved successfully.',
                        variant: 'success'
                    })
                );

                // Y actualizo el wire para que la tabla se actualice (se vaya la quote aprobada)
                return refreshApex(this.wiredResult);
            })
            .catch((e) => {
                // Si sale mal, intento sacar un mensaje decente del error 
                let msg = '';

                if (e && e.body && e.body.message) {
                    msg = e.body.message;
                } else if (e && e.body && e.body.pageErrors && e.body.pageErrors.length > 0) {
                    msg = e.body.pageErrors[0].message;
                } else if (e && e.message) {
                    msg = e.message;
                } else {
                    msg = JSON.stringify(e);
                }

                // Toast rojo
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error approving quote',
                        message: msg,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                // Pase lo que pase, apago loading
                this.isLoading = false;
            });
    }
}

