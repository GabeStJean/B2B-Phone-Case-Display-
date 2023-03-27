/** 
 * This class represents the picklist value that a Product2 instance has for a facet. A 
 * facet is picklist that defines filterable fields on a Product2 object. This class is
 * Used by {@link FacetDisplay}. 
 */
global class FacetValue implements Comparable {
	
    @auraEnabled
    public string label;
    
    @auraEnabled
    public String value;
    
    @auraEnabled
    public Boolean checked;
    
    @auraEnabled
    public Boolean disabled;
    
    @auraEnabled
    public Integer quantity;
    
    /**
     * The label and value variables are guranteed to be unique elements in a collection because 
     * the facet values come directly from the Product2 object.  
     */
    public FacetValue(String value) {
        this.label = value;
        this.value = value;
        checked = false;
        disabled = false;
        quantity = 1;
	}
    
    /**
     * This method is used to sort Facet Values ascendingly 
     */
    global Integer compareTo(Object compareTo) {
    	FacetValue compareToFacetValue = (FacetValue) compareTo;
        if (value == compareToFacetValue.value) return 0;
        if (value > compareToFacetValue.value) return 1;
        return -1;
	}
    
    public Boolean equals(Object obj) {
        if (obj instanceof FacetValue) {
            FacetValue fvObj = (FacetValue) obj;
            return value == fvObj.value;
        }
        return false;
    }
    
    public Integer hashCode() {
        return value.hashCode();
    }
    
}