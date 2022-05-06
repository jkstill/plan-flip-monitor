col rowsize format 9999.999                                                                         
select avg(                                                                                         
	nvl(vsize(decode(CUSTOMER_ID, null, null, CUSTOMER_ID)),0)+                                        
	nvl(vsize(decode(CUST_FIRST_NAME, null, null, CUST_FIRST_NAME)),0)+                                
	nvl(vsize(decode(CUST_LAST_NAME, null, null, CUST_LAST_NAME)),0)+                                  
	nvl(vsize(decode(NLS_LANGUAGE, null, null, NLS_LANGUAGE)),0)+                                      
	nvl(vsize(decode(NLS_TERRITORY, null, null, NLS_TERRITORY)),0)+                                    
	nvl(vsize(decode(CREDIT_LIMIT, null, null, CREDIT_LIMIT)),0)+                                      
	nvl(vsize(decode(CUST_EMAIL, null, null, CUST_EMAIL)),0)+                                          
	nvl(vsize(decode(ACCOUNT_MGR_ID, null, null, ACCOUNT_MGR_ID)),0)+                                  
	nvl(vsize(decode(CUSTOMER_SINCE, null, null, CUSTOMER_SINCE)),0)+                                  
	nvl(vsize(decode(CUSTOMER_CLASS, null, null, CUSTOMER_CLASS)),0)+                                  
	nvl(vsize(decode(SUGGESTIONS, null, null, SUGGESTIONS)),0)+                                        
	nvl(vsize(decode(DOB, null, null, DOB)),0)+                                                        
	nvl(vsize(decode(MAILSHOT, null, null, MAILSHOT)),0)+                                              
	nvl(vsize(decode(PARTNER_MAILSHOT, null, null, PARTNER_MAILSHOT)),0)+                              
	nvl(vsize(decode(PREFERRED_ADDRESS, null, null, PREFERRED_ADDRESS)),0)+                            
	nvl(vsize(decode(PREFERRED_CARD, null, null, PREFERRED_CARD)),0)+                                  
0) rowsize                                                                                          
from customers                                                                                      
where rownum < 1000;                                                                                
