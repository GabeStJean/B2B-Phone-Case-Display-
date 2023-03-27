import { LightningElement, wire, track } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import { CurrentPageReference } from 'lightning/navigation';
import FILTER_TEXT_DISPLAY_UPDATED_CHANNEL from '@salesforce/messageChannel/Filter_Text_Display_Updated__c';
import communityId from '@salesforce/community/Id';
import createFacetDisplay from '@salesforce/apex/ProductPageController.createFacetDisplay';

/**
 * This class creates a IU that renders each facet on the product as an input text field or combobox for filtering
 * products by values. If a user enters a value that does not exist for that facet, an error is thrown. After input
 * validation, the input values are then translated  as checkboxes and pillboxes on the productDisplay lwc. 
 */

export default class FilterTextDisplay extends LightningElement {
    // Stores the FacetDisplay.cls in Apex
    facetDisplay; 
    // Stores updates to be published
    facetDisplayUpdates;
    // Renders a facetDisplay as a combobox or text-input field
    facetTextDisplay; 
    // name of facet  => value of facet (lower case) => facetValue (object)
    facetValueMatrix = new Map();
    // name of facet => array of user input values (unformatted)
    userInputMap = new Map();
    userInputError;
    isLoading = false;
    categoryLandingPageId;
    hasContentToDisplay = false;
    @wire(MessageContext) messageContext;

    // Obtains metadata pertaining to the current page
    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference) {
       if (currentPageReference.attributes.recordId !== undefined) {
          this.isLoading = true;
          this.categoryLandingPageId = currentPageReference.attributes.recordId;
          this.refreshDisplay();
        } 
    } // getPageReferenceParameters
    
    // Refreshes the facet text display
    async refreshDisplay() {
        this.currentCategoryName = "";
        await createFacetDisplay({communityId: communityId, categoryLandingPageId: this.categoryLandingPageId})
            .then(r => {
                this.facetDisplay = r;
                this.createFacetTextDisplay();
            })
            .catch(e => {
              console.log(e);
            });
        this.finishedLoading(); 
    } // refreshDisplay

    // Creates a facet text display that renders each facet as either a combobox or text input field
    createFacetTextDisplay() {
        this.facetTextDisplay = JSON.parse(JSON.stringify(this.facetDisplay));
         // if false, the item will be an input field
        this.facetTextDisplay.forEach(e => e.isCombobox = false); 
        // Turn these values into a combobox
        this.facetTextDisplay.filter(e => e.facetName === "Packaging")[0].isCombobox = true;
        // If the facet is rendered as a combobox, configure it 
        this.facetTextDisplay.filter(e => e.isCombobox === true)
                            .forEach(e =>  {
                                e.value = e.facetValues[0].value;
                                e.options = e.facetValues;
                            });
    } // createFacetTextDisplay

   
    /**
    * Maps the user input by using the field label as the key and it's contents as the value
    * 
    * Items in a input text field are delimited by semicolons.
    */
    createUserInputMap() {
        let textInput = [];
        let comboboxInput = [];
        // Since deliminated values are surrounded by white spaces, the values will be trimmed upon event handling
        textInput = [...this.template.querySelectorAll('lightning-input')].filter(e => e.name === "textInput").map(e => {
            return {
                facetName: e.label,
                value: e.value,
            }
        });
        // Parse each delimmeted item into a array
        for (const item of textInput) {
            item.value = item.value.split(';')
        }
        
        comboboxInput = [...this.template.querySelectorAll('lightning-combobox')].filter(e => e.name === "combobox").map(e => {
            return {
                facetName: e.label,
                value: [e.value],
            }
        });

        let userInput = textInput.concat(comboboxInput);
        // Create the userInputMap
        userInput.forEach( e => { 
            this.userInputMap.set(e.facetName, e.value)
        });
    }

     // Creates a matrix of facet names => value of facet (lower case) => FacetValue (Apex object). 
    createFacetValueMatrix() {
        const fvMap = new Map();
        for (const fd of this.facetDisplayUpdates) {
            fvMap.clear();
            for (const fv of fd.facetValues) {
                fvMap.set(fv.value.toLowerCase(), fv);
            }
            this.facetValueMatrix.set(fd.facetName, new Map(fvMap));
        }
    }

    /**
     * Translates user text input into checked values on a facet display. The datastructure is then published
     * on a subscriber channel.
     */
    filterButtonHandler(event) {
        this.isLoading = true;
        this.userInputError = '';
        let facetPillbox = [];
        this.facetDisplayUpdates = JSON.parse(JSON.stringify(this.facetDisplay))
        this.createUserInputMap();
        this.createFacetValueMatrix();

        // Evaluate user input and evalueate it into facet value objects
        for (const fd of this.facetDisplayUpdates) {
            let userInputList = this.userInputMap.get(fd.facetName);
            for (const userInput of userInputList) {
                let formattedInput = userInput.trim().toLowerCase();
                // facetValue is a List<FacetValue> in Apex
                let facetValue = this.facetValueMatrix.get(fd.facetName).get(formattedInput);
                if (formattedInput !== "") {
                    if (facetValue === undefined) {
                        this.userInputError = '* Invalid filter \"' + userInput.trim() + '\" on facet ' + fd.facetName;
                        this.isLoading = false;
                        return;
                    } else {
                        facetValue.checked = true;
                        facetPillbox.push({label: fd.facetName + ': ' + facetValue.value});
                    }
                }
            } // for
        } // filterButtonHandler
        
        // update facet display
        for (const fd of this.facetDisplayUpdates) {
            let facetValues = Array.from(this.facetValueMatrix.get(fd.facetName).values());
            fd.facetValues = facetValues;
        }
        // Communicate with the product display component 
        const payload = {
                facetDisplay:  this.facetDisplayUpdates,
                facetPillbox: facetPillbox,
                categoryLandingPageId: this.categoryLandingPageId,
            };
        publish(this.messageContext,FILTER_TEXT_DISPLAY_UPDATED_CHANNEL, payload);
        this.finishedLoading();
    }

   
    finishedLoading() {
        this.isLoading = false;
        this.hasContentToDisplay = true;
    } // finishedLoading

}