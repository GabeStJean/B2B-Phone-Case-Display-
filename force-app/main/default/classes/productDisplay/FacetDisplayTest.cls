@isTest
public class FacetDisplayTest {
	
    @isTest
    static void getSelectedFacetsTest() {
        FacetDisplay colorFd = new FacetDisplay('Color',
                                           new List<FacetValue> {
                                               new FacetValue('Blue'),
                                               new FacetValue('Black'), 
                                               new FacetValue('Grey'),
                                               new FacetValue('Pink')
                                           });
        colorFd.facetValues.get(0).checked = true;
        colorFd.facetValues.get(2).checked = true;
  
        List<String> selectedFacets = colorFd.getSelectedFacets();
        String selectedFacetsStr = String.join(selectedFacets, ' ');
        for (FacetValue fv : colorFd.facetValues) {
            if (fv.checked == true) {
                System.assert(selectedFacetsStr.contains(fv.value), 
                              'Failure: ' + fv.value + ' is not a selected facet');
            }
        } // for
    }
    @isTest
    static void clearQuantityTest() {
        FacetDisplay colorFd = new FacetDisplay('Color',
                                           new List<FacetValue> {
                                               new FacetValue('Blue'),
                                               new FacetValue('Black'), 
                                               new FacetValue('Grey'),
                                               new FacetValue('Pink')
                                           });
        colorFd.facetValues.get(0).quantity = -2;
        colorFd.facetValues.get(2).quantity = 4;
        colorFd.clearQuantity();
        for (FacetValue fv : colorFd.facetValues) {
            System.Assert(fv.quantity == 0, 
                          'Failure: FacetValue quantity for ' + fv.value + 
                          ' is ' + fv.quantity + ' and not zero');
        }
    }
    
    @isTest
	static void testParse() {
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
		List<FacetDisplay> facetDisplayList = new List<FacetDisplay>();
        facetDisplayList.add(colorFd);
        facetDisplayList.add(packagingFd);

		String json = JSON.serialize(facetDisplayList);
		List<FacetDisplay> obj = FacetDisplay.parseJson(json);
		System.assert(obj != null, 'Parser failure');
	}
}