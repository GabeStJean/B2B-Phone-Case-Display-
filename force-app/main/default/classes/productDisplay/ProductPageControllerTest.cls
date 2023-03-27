/**
 * Test class for ProductPageController. Ensure that all facets and field values
 * that appear in this created on the Product2 object, searchable, and indexed in the webstore.
 * if testing a user that is not an admin, ensure that the user is a customer to the 
 * websotre and has feild access to the facets on the Product2 object. 
 *
 * Admin info:
 *    Digital Cases communityID - 0DBDn000000kEsROAU
 *    Gmoney B2B store communityID - 0DBDn000000kDqvOAE 
 *    Gmoney B2B store webID '0ZEDn000000HehLOAS'
 * 
 */ 



@isTest(SeeAllData=true)
private class ProductPageControllerTest {
    
    static String userName; 
    static String communityId;
    static String categoryLandingPageId;
    static User contextUser;
    
    static {
        userName ='engineerb2b@publicis.dev';
        communityId = '0DBDn000000kDqvOAE';
        categoryLandingPageId = '0ZGDn000000M345OAC';
        contextUser = [SELECT id FROM User WHERE Username =: userName LIMIT 1];
    }

    // Use this class to obtain metadata pertaining to the communities that a user has access to
    @isTest static void displayUserCommerceIds() {     
        System.runAs(contextUser) {
            ConnectApi.CommunityPage communityPage = ConnectApi.Communities.getCommunities();
      	    for (ConnectApi.Community cp : communityPage.communities) {
            	System.debug('name: ' + cp.name);
            	System.debug('communityId: ' + cp.id);
            	System.debug('Web ID : ' + B2BUtils.resolveCommunityIdToWebstoreId(cp.id));
       		 } 
        } 
    } // displayUserCommerceIds
    
   @isTest static void testB2BUtils() {
        System.runAs(contextUser) {
             String webstoreIdToTest = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
             System.assert(webstoreIdToTest != null, 'Test failed: Webstore Id is null');
        }
   } // testB2BUtils
    
   @isTest static void getSearchResultsTest() {
        System.runAs(contextUser) {
           ConnectApi.ProductSearchResults searchResults = ProductPageController.getSearchResults(communityId,
                                                                                                  categoryLandingPageId);
           List<ConnectApi.ProductSummary> productSummaries = searchResults.productsPage.products;
		   List<String> productId = new List<String>();
           if (searchResults != null) {
               for (ConnectApi.ProductSummary ps : productSummaries) {
                   productId.add(ps.id);
			   } // for
               productId.sort();
               List<Product2> productSOQL = [SELECT id FROM Product2 WHERE id =: productId];
               if (productSOQL.size() != productSummaries.size()) {
                   System.debug('SOQL query product: ' + productSOQL);
                   System.debug('getSearchResults method: ' + productId);
                   System.assert(false,'Query mismatch: System didn\'t retrieve all queried products from the' +
                                   'ConnectApi search results');
               }
             
           } else {
               System.assert(false, 'Search results is null');
           } // if
        }       
    } // getSearchResultsTest
    
    @isTest static void createFacetDisplayTest() {
        Map<String, String> displayNameToApiMap = new Map<String, String>();
        Map<String, ConnectApi.SearchFacet> facetNameMap = new Map<String, ConnectApi.SearchFacet>();
        System.runAs(contextUser) {
            ConnectApi.ProductSearchResults searchRes = ProductPageController.getSearchResults(communityId, categoryLandingPageId);
            List<FacetDisplay> fdList = new List<FacetDisplay>(ProductPageController.createFacetDisplay(communityId, categoryLandingPageId));
            System.assert(searchRes != null, 'Search result failed');
            // Building maps
            for (ConnectApi.SearchFacet sf : searchRes.facets) {
                facetNameMap.put(sf.displayName, sf);
                displayNameToApiMap.put(sf.displayName, sf.nameOrId);
            }
            
          	List<ConnectApi.ProductSummary> productSummaries = searchRes.productsPage.products;
            // Testing facet names
            for (FacetDisplay fd : fdList) {
                String apiName = displayNameToApiMap.get(fd.facetName);
                // Check if the facet name exists for the FacetDisplay
                ConnectApi.SearchFacet connectSearchFacet = facetNameMap.get(fd.facetName);
                System.assert(connectSearchFacet != null, 
                              'The facet: ' + fd.facetName + 'is not on the product');
                String fdValuesJson = JSON.serialize(fd.facetValues);
                            
                // For each product search result, check if the facet display contains the field value for all facets on the product
                for (ConnectApi.ProductSummary ps : productSummaries) {
                    String connectFeildValue = ps.fields.get(apiName).value;
                    // if field is a multiselect picklist
                    if (connectFeildValue.contains(';')) {  
                        for (String val : connectFeildValue.split(';')) {
                            System.assert(fdValuesJson.contains(val),
                                  'The object ' + ps.name + ' (' + ps.id + ') ' + 'does not have the field value: ' +
                                   val + 'does not exist on the facet display ' +  fd);
                        } // for
                    } else {
                        System.debug(connectFeildValue);
                 	    System.assert(fdValuesJson.contains(connectFeildValue),
                                  'The object ' + ps.name + ' (' + ps.id + ') ' + 'does not have the field value: ' +
                                  connectFeildValue + 'does not exist on the facet display ' +  fd);
                    } // if	
                }// for
            } // for
        }        
    } // createFacetDisplayTest
    
   
    @isTest static void filterProductDisplaysTest() {
        String facetNameToTest = 'Color__c';
        String expectedFeildValue = 'Blue';
        List<FacetDisplay> dummyFacetDisplay = dummyFacetDisplayIphone();
        String facetDisplayJson = JSON.serialize(dummyFacetDisplayIphone());
	
        System.runAs(contextUser) {
           Map<String, Object> resultsMap = ProductPageController.filterProductDisplay(communityId, 
                                                                                       categoryLandingPageId,
                                                                                       facetDisplayJson);
           for (String name : resultsMap.keySet()) {
                System.Assert(name == 'filterResults' || name ==  'facetDisplay', 
                              'Failure: Map key names are not configured properly. Ensure that they are named ' +
                               '\'filterResults\' and \'facetDisplay\'');
           }
           // First, test the filter results
           List<ConnectApi.ProductSummary> productSummary = (List<ConnectApi.ProductSummary>)resultsMap.get('filterResults');
           System.Assert(productSummary != null, 'filterProductDisplay Failed: Search results is null');

           // for each product result, check if the field value matches the facet criteria
           for (ConnectApi.ProductSummary ps : productSummary) { 
               String connectFeildValue = ps.fields.get(facetNameToTest).value;
               System.assert(connectFeildValue == expectedFeildValue, 
                       'The object ' + ps.name + ' (' + ps.id + ') ' + 'does not have the field value: ' + 
                       connectFeildValue + ' for the facet ' + facetNameToTest + ' in the Facet Display: ' +
                       dummyFacetDisplay);
            } 
            /**
             *  Secondly, test the facetDisplay by ensuring that the quanity and checked values areaccurate for each facet
             */
            List<FacetDisplay> updatedFacetDisplay = (List<FacetDisplay>) resultsMap.get('facetDisplay');
            System.debug('------ old facetDisplay-----');
            facetDisplayDebug(dummyFacetDisplay);
            System.debug('--- updated facetDisplay ---');  
            facetDisplayDebug(updatedFacetDisplay);
        	
         
        }       
    } // filterProductDisplaysTest
    
    
    /** 
     * Creates hardcoded facet display values for testing. Ensure that facet values in this method are
     * created on the Product2 object, searchable, and indexed in the webstore.
     */
     static List<FacetDisplay> dummyFacetDisplayIphone() {
        List<FacetDisplay> fdList = new List<FacetDisplay>();
        FacetDisplay brandFd = new FacetDisplay('Brand',
                                           new List<FacetValue> {
                                               new FacetValue('Apple')
                                           });
        FacetDisplay productLineFd = new FacetDisplay('Product Line',
                                           new List<FacetValue> {
                                               new FacetValue('Defender Series'),
                                               new FacetValue('Commuter Series'),  
                                               new FacetValue('Lumen Series')
                                           });
        FacetDisplay compatibilityFd = new FacetDisplay('Compatibility',
                                           new List<FacetValue> {
                                               new FacetValue('iPhone 13'),
                                               new FacetValue('iPhone 14')                                              
                                           });
        FacetDisplay featuresFd = new FacetDisplay('Features',
                                           new List<FacetValue> {
                                               new FacetValue('3X Tested To Military Standard'),
                                               new FacetValue('4X Tested To Military Standard'),                                          
                                               new FacetValue('Antimicrobial')     
                                           });
        FacetDisplay colorFd = new FacetDisplay('Color',
                                           new List<FacetValue> {
                                               new FacetValue('Blue'),
                                               new FacetValue('Black'), 
                                               new FacetValue('Grey'),
                                               new FacetValue('Pink')
                                           });
        FacetDisplay packagingFd = new FacetDisplay('Packaging',
                                           new List<FacetValue> {
                                               new FacetValue('Pro-Pack'),
                                               new FacetValue('Retail')                                              
                                           });
        
        // brandFd.facetValues.get(0).checked = true;
    	// productLineFd.facetValues.get(0).checked = true;
    	// compatibilityFd.facetValues.get(0).checked = true;
    	// featuresFd.facetValues.get(0).checked = true;
        colorFd.facetValues.get(0).checked = true;
        // packagingFd.facetValues.get(0).checked = true;


        fdList.add(brandFd);
        fdList.add(productLineFd);
        fdList.add(compatibilityFd);
        fdList.add(featuresFd);
        fdList.add(colorFd);
        fdList.add(packagingFd);                                       
        return fdList;
    }
    
    static void facetDisplayDebug(List<FacetDisplay> facetDisplay) {
        for (FacetDisplay fd: facetDisplay)    {
            String str = '';
            for (FacetValue fv: fd.facetValues) {
                str += fv.value + ' ' + fv.quantity + '; ';  
             }
                System.debug(fd.facetName + ' :' + str);
           }           
    } // facetDisplayDebug
    
	
} // ProductPageControllerTest