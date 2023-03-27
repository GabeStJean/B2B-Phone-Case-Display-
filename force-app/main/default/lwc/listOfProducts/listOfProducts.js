import { LightningElement, api } from 'lwc';

// Displays products from a stores catalog
export default class listOfProducts extends LightningElement {
    @api productList; // Stores a List<ConnectApi.ProductSummary> object
    
    connectedCallback() {
    } //connectedCallback
}