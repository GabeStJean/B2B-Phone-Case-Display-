import { LightningElement, api, wire } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import FILTER_TEXT_DISPLAY_UPDATED_CHANNEL from '@salesforce/messageChannel/Filter_Text_Display_Updated__c';
import communityId from '@salesforce/community/Id';
import filterProductDisplay from '@salesforce/apex/ProductPageController.filterProductDisplay';

// Displays facets and their field values as checkboxes 
export default class filterCheckboxDisplay extends LightningElement {
    @api facetDisplay;
    @api categoryLandingPageId;
    @api facetPillbox;
    @wire(MessageContext) messageContext;
    subscription = null;
    isLoading = false;
    count = 0;

    // Handler for when a checkbox is clicked
    async handleCheckbox(event) {
        this.isLoading = true;
        let facetPillbox = JSON.parse(JSON.stringify(this.facetPillbox));
        let facetDisplay = JSON.parse(JSON.stringify(this.facetDisplay));
        let checkboxValue = event.target.checked;
        let facetDisplayName =  event.target.name;
        let facetValueName = event.target.label;
      
        // update the facet display
        let selectedFacetValue = facetDisplay
                                          .filter(item => item.facetName === facetDisplayName)[0].facetValues
                                          .filter(item => item.value === event.target.label)[0];
        selectedFacetValue.checked = checkboxValue;
        if (checkboxValue === false) { // remove item from pillbox
            facetPillbox = facetPillbox.filter( e =>   e.label !== facetDisplayName + ": " + facetValueName);
        } else { // add item
            facetPillbox.push({label: facetDisplayName + ": " + facetValueName});
        }

        await filterProductDisplay({communityId: communityId, categoryLandingPageId: this.categoryLandingPageId,  
                              facetDisplayJson: JSON.stringify(facetDisplay)})
                .then(r => {
                  let filterResults = r.filterResults;
                  facetDisplay = r.facetDisplay;
                  const checkboxSelectEvent = new CustomEvent("checkboxselect", {
                      detail:{facetDisplay: facetDisplay, facetPillbox: facetPillbox, filterResults: filterResults}
                  });  
                  this.dispatchEvent(checkboxSelectEvent);   
              })
                .catch(e => {
                  console.log('handle checkbox error: ', e);
                });
        this.finishedLoading();
    } // handleCheckbox

    /** 
     * Updates the facet display when a pill box is x'ed out
     * 
     * This method is invoked by productDisplay.js
     */
    @api
    async removePillboxItem(event) {
        this.isLoading = true;
        let facetDisplay = JSON.parse(JSON.stringify(this.facetDisplay));
        let facetPillbox = JSON.parse(JSON.stringify(this.facetPillbox));
        const index = event.detail.index;
        let pillBoxLabel =  event.detail.item.label;
        let facetDisplayName =  pillBoxLabel.substring(0, pillBoxLabel.indexOf(":")).trim();
        let facetValueName = pillBoxLabel.substring(pillBoxLabel.indexOf(":") + 1).trim();

         // remove the selected pillbox
        facetPillbox.splice(index, 1) 
        let selectedFacetValue = facetDisplay
                                        .filter(item => item.facetName === facetDisplayName)[0].facetValues
                                        .filter(item => item.value === facetValueName)[0];
        selectedFacetValue.checked = false;
        await filterProductDisplay({communityId: communityId, categoryLandingPageId: this.categoryLandingPageId, 
                            facetDisplayJson: JSON.stringify(facetDisplay)})
              .then(r => {
                let filterResults = r.filterResults;
                facetDisplay = r.facetDisplay;
                const removePillEvent = new CustomEvent("removepillevent", {
                    detail:{facetDisplay: facetDisplay, facetPillbox: facetPillbox, filterResults: filterResults}
                });  
                this.dispatchEvent(removePillEvent);         
              })
              .catch(e => {
                console.log('Remove pillbox error: ', e);
              });
         this.finishedLoading();
    } // removePillboxItem


    finishedLoading() {
      this.isLoading = false;
    }

    // To receive updates from the filter text display component
    handleSubscribe() {
      this.subscription = subscribe(
        this.messageContext,
        FILTER_TEXT_DISPLAY_UPDATED_CHANNEL,
        (message) => this.handleFilterTextDisplay(message)
      );
    }

     // Translates values from the filter text display into the facet display and updates it
     async handleFilterTextDisplay(message) {
        let facetDisplay = message.facetDisplay;
        let categoryLandingPageId = message.categoryLandingPageId;
        let facetPillbox = message.facetPillbox;
        await filterProductDisplay({communityId: communityId, categoryLandingPageId: categoryLandingPageId, 
                            facetDisplayJson: JSON.stringify(facetDisplay)})
              .then(r => {
                let filterResults = r.filterResults;
                facetDisplay = r.facetDisplay;
                const facetTextDisplayUpdate = new CustomEvent("filtertextdisplayupdate", {
                    detail:{facetDisplay: facetDisplay, facetPillbox: facetPillbox, filterResults: filterResults}
                });  
                this.dispatchEvent(facetTextDisplayUpdate); 
              })
              .catch(e => {
                console.log('Handle LMS errors: ', e);
              });
        
    }
   
    connectedCallback() {
        this.handleSubscribe();
    } // connectedCallback


}