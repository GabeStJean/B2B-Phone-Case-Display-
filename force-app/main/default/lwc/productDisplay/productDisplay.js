import { LightningElement, api, wire } from 'lwc';
import communityId from '@salesforce/community/Id';
import getSearchResults from '@salesforce/apex/ProductPageController.getSearchResults';
import createFacetDisplay from '@salesforce/apex/ProductPageController.createFacetDisplay';
import { CurrentPageReference } from 'lightning/navigation';

// This component serves as the main container for c-filter-checkbox-display and c-list-of-products
export default class FilterPrompt extends LightningElement {
   
    @api productList; // Stores a List<ConnectApi.ProductSummary> object
    @api facetDisplay; // Stores a List<FacetDisplay> object 
    @api categoryLandingPageId;
    @api facetPillbox = [];
    currentCategoryPath;
    currentCategoryName;
    isFacetAdded = false;
    isLoading = false;
    hasContentToDisplay = false;

    // Obtains metadata pertaining to the current page
    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference) {
       if (currentPageReference.attributes.recordId !== undefined) {
          this.isLoading = true;
          this.currentCategoryName = "";
          this.categoryLandingPageId = currentPageReference.attributes.recordId;
          this.currentCategoryPath = currentPageReference.state.categoryPath; 
          this.refreshProductDisplay();
          let categoryNameIndex = this.currentCategoryPath.lastIndexOf("/") + 1;
          this.currentCategoryName = this.currentCategoryPath.substring(categoryNameIndex)
                                                              .toUpperCase()
                                                              .replaceAll("-", " ");
          
        } // if
    }

   async refreshProductDisplay(event) {
         this.facetPillbox = [];
         this.isFacetAdded = false;
         await getSearchResults({communityId: communityId, categoryLandingPageId: this.categoryLandingPageId})
            .then(r => {
              this.productList = r.productsPage.products;         
            })
            .catch(e => {
              console.log(e);
            });

         await createFacetDisplay({communityId: communityId, categoryLandingPageId: this.categoryLandingPageId})
            .then(r => {
                this.facetDisplay = JSON.parse(JSON.stringify(r));               
            })
            .catch(e => {
              console.log(e);
            });
        this.finishedLoading();
    } // refreshProductDisplay 

    finishedLoading() {
      this.isLoading = false;
      this.hasContentToDisplay = true;
    }

    // handles all events fired from c-filter-checkbox-display
    handleFilterCheckboxDisplay(event) {
      this.facetDisplay = event.detail.facetDisplay;
      this.facetPillbox = event.detail.facetPillbox;
      this.productList = event.detail.filterResults;
      if (this.facetPillbox.length === 0) {
        this.isFacetAdded = false;
      } else {
        this.isFacetAdded = true;
      }
    }

    // When a pillbox is removed from the UI
    handlePillboxItemRemove(event) {
      this.template.querySelector('c-filter-checkbox-display').removePillboxItem(event);
    }

}