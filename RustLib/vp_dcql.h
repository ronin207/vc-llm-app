#ifndef VP_DCQL_H
#define VP_DCQL_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Create a Verifiable Presentation from DCQL query and signed VC
 *
 * @param dcql_query - DCQL query as JSON string (null-terminated)
 * @param signed_credential - Signed VC as JSON string (null-terminated)
 * @param challenge - Optional challenge string (can be NULL)
 * @return VP as JSON string, or error message prefixed with "ERROR: "
 *         Caller must free the returned string with vp_dcql_free_string()
 */
char* vp_dcql_create_presentation(
    const char* dcql_query,
    const char* signed_credential,
    const char* challenge
);

/**
 * Free a string returned by vp_dcql_create_presentation
 *
 * @param s - String to free (must not be NULL)
 */
void vp_dcql_free_string(char* s);

#ifdef __cplusplus
}
#endif

#endif // VP_DCQL_H
