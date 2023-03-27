/** 
 * This class utilizes Connect Apex to integrate search results from a B2B Commerce store
 * 
 * Important parameters:
 * communityId - the ID of the experience cloud site that the context user is accessing
 * webstoreId - the ID of the webstore being accessed by the User
 *     * To obtain manually:
 *         - Go to the store's workspace on the Lightning platform
 *         - Copy the ID in the URL
 * effectiveAccountId - the ID of the account for which the request is made. If null, defaults to the account ID
 *                      of the context user.
 *     * To get effective AccountId:
 *         - Get the ID of User with UserInfo.getUserId()
 *         - Query the account with matching user ID
*/                        

public without sharing class ProductPageController {
     
    /**
     * Returns the search results from the ConnectApi Commerce Search class.
     * 
     * @param communityId - the ID of the experience cloud site that the context user is accessing
     * @param categoryLandingPageId - the literals used to generate a search result
     */
    @AuraEnabled(cacheable=false)
    public static ConnectApi.ProductSearchResults getSearchResults(String communityId, String categoryLandingPageId) {
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        ConnectApi.ProductSearchInput input = new ConnectApi.ProductSearchInput();
        input.categoryId = categoryLandingPageId;
        input.includePrices = True;
        ConnectApi.ProductSearchResults searchResults = ConnectApi.CommerceSearch.searchProducts(webstoreId, null, input);
        return searchResults;
	} // getSearchResults
    
    /** Maps facet names (keys) to their Api names 
     * 
     * @param connectApiFacetResultsJson - the serialized ConnectApi.SearchFacet results from the product search results
     */
    private static Map<String, ConnectApi.SearchFacet> createFacetResultsMap(List<ConnectApi.SearchFacet> searchFacet) {
        // Recieved JSON parser errors when trying to cast directly into List<ConnectApi.SearchFacet>, so a custom class is used
        Map<String, ConnectApi.SearchFacet> facetResultsMap = new Map<String, ConnectApi.SearchFacet>();
        for (ConnectApi.SearchFacet facet : searchFacet) {
            facetResultsMap.put(facet.displayName, facet);
		}
        return facetResultsMap;
	}
    
    /**
     * Returns a list of facet displays from all the products within a category landing page.
     * 
     * @param communityId - the ID of the experience cloud site that the context user is accessing
     * @param categoryLandingPageId - the literals used to generate a search result
     */
    @AuraEnabled(cacheable=false)
    public static List<FacetDisplay> createFacetDisplay(String communityId, String categoryLandingPageId) {
      	ConnectApi.ProductSearchResults searchResults = getSearchResults(communityId, categoryLandingPageId);
        List<FacetDisplay> fdList = new List<FacetDisplay>();
	    
        // facet name => value of facet => facetValue
        Map<String, Map<String, FacetValue>> fvMatrix = getFacetValueMatrix(searchResults);
        
		// convert facet value matrix into a list of Facet Displays
        for (String facetName : fvMatrix.keySet()) {
            Map<String, FacetValue> fvMap = fvMatrix.get(facetName);
            List<FacetValue> fvList = fvMap.values();
            fvList.sort();
            FacetDisplay fd = new FacetDisplay(facetName, fvList);
            fdList.add(fd);
        }
       
        return fdList;
	} // createFacetPicklistMap
    
    /**
     * Creates a datastructure that maps all field values returned from a connect api search results to 
     * their facet name.
     * 
     * @param searchResults - Contains all the products that appear on a category landing page
     * 
     * Returns a three dimensional map (facet name => value of facet => FacetValue) so that updating data pertaining
     * to FacetValue can be made easier. This structure can also be converted into a FacetDisplay object.
     */
    private static Map<String, Map<String, FacetValue>> getFacetValueMatrix(ConnectApi.ProductSearchResults searchResults) {
        Map<String, Map<String, FacetValue>> fvMatrix = new  Map<String, Map<String, FacetValue>>();
        
        // maps facet api names (keys) to their display name
        Map<String, String> facetApiMap = new Map<String, String>(); 
        
        // maps facet display names (keys) to their facet info
        Map<String, ConnectApi.SearchFacet> facetResultsMap = new Map<String, ConnectApi.SearchFacet>();
        for (ConnectApi.SearchFacet facet : searchResults.facets) {
            facetApiMap.put(facet.nameOrId, facet.displayName); 
            facetResultsMap.put(facet.displayName, facet); 
        } // for
  
        // For each facet in the product search results, store field metadata in FacetValue
        for (String facetApiName : facetApiMap.keySet()) {
            String displayName =  facetApiMap.get(facetApiName);
            Map<String, FacetValue> fvMap = new Map<String, FacetValue>();
            for (ConnectApi.ProductSummary ps : searchResults.productsPage.products) {
                String fieldValue = ps.fields.get(facetApiName).value;
                // If the field is a multiselect, parse multiselect values into a collection
                if (facetResultsMap.get(displayName).displayType == ConnectApi.CommerceSearchFacetDisplayType.MultiSelect) {
                    for (String value : fieldValue.split(';')) {
                        if (fvMap.containsKey(value)) { // if the facet already exists
                            FacetValue fv = fvMap.get(value);
                            fv.quantity += 1;
                        } else {
                            fvMap.put(value, new FacetValue(value));
                        }
                    } // for 
                } else {
                    if (fvMap.containsKey(fieldValue)) {
                        FacetValue fv = fvMap.get(fieldValue);
                        fv.quantity += 1;
                    } else {
                        fvMap.put(fieldValue, new FacetValue(fieldValue));
                    }
                }   
			} // for : product summary
          	fvMatrix.put(displayName, fvMap);
        }
        return fvMatrix;
    } // getFacetValueMatrix
    
   /**
     * Adds refinements to a search key so that it can return a map containing the list of returned
     * products and an updated FacetDisplay. 
     * 
     * @param communityId - the ID of the experience cloud site that the context user is accessing
     * @param categoryLandingPageId - the literals used to generate a search result
	 * @param facetDisplayJson - the list of facet display objects from the product filter list.
	 *                           Must not be passed in as a null value
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> filterProductDisplay(String communityId, String categoryLandingPageId, 
                                                                       String facetDisplayJson) {
        ConnectApi.ProductSearchResults searchResults = getSearchResults(communityId, categoryLandingPageId);
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);  
		
        List<FacetDisplay> facetDisplay = FacetDisplay.parseJson(facetDisplayJson);                      
     	Map<String, ConnectApi.SearchFacet> facetResultsMap = createFacetResultsMap(searchResults.facets);
        // Prepare the search results                                                                   
        ConnectApi.ProductSearchInput sInput = new ConnectApi.ProductSearchInput();
        ConnectApi.DistinctValueRefinementInput rInput;
		List<ConnectApi.RefinementInput> rInputList = new List<ConnectApi.RefinementInput>();     
		sInput.categoryId = categoryLandingPageId;  
        sinput.includePrices = True;
        // Refine the search input
        for (FacetDisplay fd : facetDisplay) {
            rInput = new ConnectApi.DistinctValueRefinementInput();
            ConnectApi.SearchFacet facetInfo = facetResultsMap.get(fd.facetName);
            String apiName = facetInfo.nameOrId;         
            if (facetInfo.attributeType == ConnectApi.CommerceSearchAttributeType.Custom) {
            	rInput.attributeType = ConnectApi.CommerceSearchAttributeType.Custom;
            } else if (facetInfo.attributeType == ConnectApi.CommerceSearchAttributeType.Standard) {
                rInput.attributeType = ConnectApi.CommerceSearchAttributeType.Standard;
            } else if (facetInfo.attributeType == ConnectApi.CommerceSearchAttributeType.ProductAttribute) {
                rInput.attributeType = ConnectApi.CommerceSearchAttributeType.ProductAttribute;
            } else {
                rInput.attributeType = ConnectApi.CommerceSearchAttributeType.ProductCategory;
            }
			rInput.nameOrId = apiName;
       	    List<String> valuesToRefine = new List<String>(fd.getSelectedFacets());
			rInput.values = valuesToRefine;
			rInputList.add(rInput);
        } // for
		sInput.refinements = rInputList;

		ConnectApi.ProductSearchResults rSearchResults = ConnectApi.CommerceSearch.searchProducts(webstoreId, null, sInput);
		List<FacetDisplay> updatedFacetDisplay = updateFacetDisplay(rSearchResults, facetDisplay);
    
       
        Map<String, Object> updatesMap = new Map<String, Object>();
        updatesMap.put('filterResults', rSearchResults.productsPage.products);
        updatesMap.put('facetDisplay', updatedFacetDisplay);                                                                  
        return updatesMap;
    } // filterSearch
    
    /**
    * Returns a facetDisplay object with an updated quantity count for each facet value that appears
    * from a refined search result.
    * 
    * @param rSearchResults - a search result containing products that match the criteria
    * @param facetDisplay - displays all facets from a unrefined search results and their metadata 
    */
    private static List<FacetDisplay> updateFacetDisplay(ConnectApi.ProductSearchResults rSearchResults, 
                                                  List<FacetDisplay> facetDisplay) {
        // facet name => value of facet => facetValue           
        // Stores the updated quantity count for each facet that is returned                                                      
        Map<String, Map<String, FacetValue>> fvMatrix = getFacetValueMatrix(rSearchResults);
         
        // if no results are returned
        if (fvMatrix == null) {
            for (FacetDisplay fd : facetDisplay) { 
                fd.clearQuantity();
            }
            return facetDisplay;
        }
        
        /**
         * Since search input refinement does not return the facet values that do not match the
         * match the search critera, add them to the facet matrix if missing
         */                                                                       
        for (FacetDisplay fd : facetDisplay) {
            Map<String, FacetValue> fvMap = fvMatrix.get(fd.facetName);
            for (FacetValue fv : fd.facetValues) {
                if (fvMap.containsKey(fv.value)) {
                    fvMap.get(fv.value).checked = fv.checked;
                } else {
                    fv.quantity = 0;
                    fv.disabled = true;
                    fvMap.put(fv.value, fv);
                }
            } // for : FacetValue
         }        
          
       List<FacetDisplay> updatedFacetDisplay = new List<FacetDisplay>();
                                    
		// convert facet value matrix into a list of Field Displays
        for (String facetName : fvMatrix.keySet()) {
            Map<String, FacetValue> fvMap = fvMatrix.get(facetName);
            List<FacetValue> fvList = fvMap.values();
            fvList.sort();
            FacetDisplay fd = new FacetDisplay(facetName, fvList);
            updatedFacetDisplay.add(fd);
        }   
        return updatedFacetDisplay;
    } // updateFacetDisplay
    
   
} // ProductPageController