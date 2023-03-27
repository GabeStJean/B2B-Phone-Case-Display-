/**
 *
 */
public with sharing class B2BUtils {   
  // A cache which maps community Ids to WebStore Ids
  private static Map<String, String> communityIdToWebStoreIdCache = new Map<String, String>();

  /**
   * Returns the webstoreId corresponding to the community Id for the context user.
   * 
   * @param communityId - the ID of the experience cloud site that the context user is accessing 
   */
  public static String resolveCommunityIdToWebstoreId(String communityId) {
    if (communityIdToWebStoreIdCache.containsKey(communityId)) {
      return communityIdToWebStoreIdCache.get(communityId);
    } else {
      String webStoreId = [
        SELECT WebStoreId
        FROM WebStoreNetwork
        WHERE NetworkId = :communityId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ]
      .WebStoreId;
      communityIdToWebStoreIdCache.put(communityId, webStoreId);
      return webStoreId;
    }
  }

}