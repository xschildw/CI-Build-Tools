package org.sagebionetworks.createtestuser;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Header;
import io.jsonwebtoken.Jwt;
import io.jsonwebtoken.Jwts;
import org.sagebionetworks.client.SynapseAdminClientImpl;
import org.sagebionetworks.client.exceptions.SynapseException;
import org.sagebionetworks.repo.model.auth.LoginRequest;
import org.sagebionetworks.repo.model.auth.LoginResponse;
import org.sagebionetworks.repo.model.auth.NewIntegrationTestUser;
import org.sagebionetworks.simpleHttpClient.SimpleHttpClientConfig;

public class App {

	public static void main(String[] args) throws Exception {
		String userName = args[0];
		String apiKey = args[1];
		String testUSerName = args[2];
		String testUserPassword = args[3];
		String testUserEmail = args[4];

		SynapseAdminClientImpl client = createNewConnection(userName, apiKey);
		NewIntegrationTestUser user = new NewIntegrationTestUser()
				.setUsername(testUSerName)
				.setPassword(testUserPassword)
				.setEmail(testUserEmail)
				.setTou(true);
		LoginResponse response = client.createIntegrationTestUser(user);
		String accessToken = response.getAccessToken();
		String subject = App.getSubjectFromJWTAccessToken(accessToken);
		client.setCertifiedUserStatus(subject, true);
		System.out.println(String.format("Test user '%s' created, ID=%s .", testUSerName, subject));
	}

	private static SynapseAdminClientImpl createNewConnection(String userName, String apiKey) {
		String DEV_REPO_ENDPOINT = "https://repo-dev.dev.sagebase.org/repo/v1";
		String DEV_AUTH_ENDPOINT = "https://repo-dev.dev.sagebase.org/auth/v1";
		String DEV_FILE_ENDPOINT = "https://repo-dev.dev.sagebase.org/file/v1";
		SimpleHttpClientConfig config = new SimpleHttpClientConfig();
		config.setConnectTimeoutMs(1000*60);
		config.setSocketTimeoutMs(1000*60*10);
		SynapseAdminClientImpl client = new SynapseAdminClientImpl(config);
		client.setAuthEndpoint(DEV_AUTH_ENDPOINT);
		client.setRepositoryEndpoint(DEV_REPO_ENDPOINT);
		client.setFileEndpoint(DEV_FILE_ENDPOINT);
		client.setUsername(userName);
		client.setApiKey(apiKey);
		return client;
	}

	public static String getSubjectFromJWTAccessToken(String accessToken) {
		return getUnsignedJWTFromToken(accessToken).getBody().getSubject();
	}

	private static Jwt<Header, Claims> getUnsignedJWTFromToken(String token) {
		String[] pieces = token.split("\\.");
		if (pieces.length!=3) throw new IllegalArgumentException("Expected three sections of the token but found "+pieces.length);
		String unsignedToken = pieces[0]+"."+pieces[1]+".";
		// Expiration time is checked by the parser
		return Jwts.parser().parseClaimsJwt(unsignedToken);
	}

}
