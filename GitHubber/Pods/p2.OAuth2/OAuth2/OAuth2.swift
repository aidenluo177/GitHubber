//
//  OAuth2.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/4/14.
//  Copyright 2014 Pascal Pfiffner
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation


/**
    Base class for specific OAuth2 authentication flow implementations.
 */
public class OAuth2: OAuth2Base {
	
	public class var grantType: String {
		return "__undefined"
	}
	
	public class var responseType: String? {
		return nil
	}
	
	/// Client setup
	public let clientConfig: OAuth2ClientConfig
	
	/// Client-side authorization options.
	public var authConfig = OAuth2AuthConfig()
	
	/// The client id.
	public final var clientId: String? {
		get { return clientConfig.clientId }
		set { clientConfig.clientId = newValue }
	}
	
	/// The client secret, usually only needed for code grant.
	public final var clientSecret: String? {
		get { return clientConfig.clientSecret }
		set { clientConfig.clientSecret = newValue }
	}
	
	/// The URL to authorize against.
	public final var authURL: NSURL {
		get { return clientConfig.authorizeURL }
	}

	/// The URL string where we can exchange a code for a token; if nil `authURL` will be used.
	public final var tokenURL: NSURL? {
		get { return clientConfig.tokenURL }
	}
	
	/// The scope currently in use.
	public var scope: String? {
		get { return clientConfig.scope }
		set { clientConfig.scope = newValue }
	}
	
	/// The redirect URL string to use.
	public var redirect: String? {
		get { return clientConfig.redirect }
		set { clientConfig.redirect = newValue }
	}
	
	/// Context for the current auth dance.
	var context = OAuth2ContextStore()
	
	/// The receiver's access token.
	public var accessToken: String? {
		get { return clientConfig.accessToken }
		set { clientConfig.accessToken = newValue }
	}
	
	/// The access token's expiry date.
	public var accessTokenExpiry: NSDate? {
		get { return clientConfig.accessTokenExpiry }
		set { clientConfig.accessTokenExpiry = newValue }
	}
	
	/// The receiver's long-time refresh token.
	public var refreshToken: String? {
		get { return clientConfig.refreshToken }
		set { clientConfig.refreshToken = newValue }
	}
	
	/// Closure called on successful authentication on the main thread.
	public final var onAuthorize: ((parameters: OAuth2JSON) -> Void)?
	
	/// When authorization fails (if error is not nil) or is cancelled, this block is executed on the main thread.
	public final var onFailure: ((error: ErrorType?) -> Void)?
	
	/**
	Closure called after onAuthorize OR onFailure, on the main thread; useful for cleanup operations.
	
	- parameter wasFailure: Bool indicating success or failure
	- parameter error: ErrorType describing the reason for failure, as supplied to the `onFailure` callback. If it is nil and `wasFailure`
	is true, the process was aborted.
	*/
	public final var afterAuthorizeOrFailure: ((wasFailure: Bool, error: ErrorType?) -> Void)?
	
	/// Same as `afterAuthorizeOrFailure`, but only for internal use and called right BEFORE the public variant.
	final var internalAfterAuthorizeOrFailure: ((wasFailure: Bool, error: ErrorType?) -> Void)?
	
	
	/**
	Designated initializer.
	
	The following settings keys are currently supported:
	
	- client_id (string)
	- client_secret (string), usually only needed for code grant
	- authorize_uri (URL-string)
	- token_uri (URL-string), if omitted the authorize_uri will be used to obtain tokens
	- redirect_uris (list of URL-strings)
	- scope (string)
	
	- client_name (string)
	- registration_uri (URL-string)
	- logo_uri (URL-string)
	
	- keychain (bool, true by default, applies to using the system keychain)
	- verbose (bool, false by default, applies to client logging)
	- secret_in_body (bool, false by default, forces the flow to use the request body for the client secret)
	- token_assume_unexpired (bool, true by default, whether to use access tokens that do not come with an "expires_in" parameter)
	- title (string, to be shown in views shown by the framework)
	*/
	public override init(settings: OAuth2JSON) {
		clientConfig = OAuth2ClientConfig(settings: settings)
		
		// auth configuration options
		if let inBody = settings["secret_in_body"] as? Bool {
			authConfig.secretInBody = inBody
		}
		if let ttl = settings["title"] as? String {
			authConfig.ui.title = ttl
		}
		super.init(settings: settings)
	}
	
	
	// MARK: - Keychain Integration
	
	public override func keychainServiceName() -> String {
		return authURL.description
	}
	
	override func updateFromKeychainItems(items: [String : NSCoding]) {
		for message in clientConfig.updateFromStorableItems(items) {
			logIfVerbose(message)
		}
		authConfig.secretInBody = (clientConfig.endpointAuthMethod == OAuth2EndpointAuthMethod.ClientSecretPost)
	}
	
	override func storableCredentialItems() -> [String : NSCoding]? {
		return clientConfig.storableCredentialItems()
	}
	
	override func storableTokenItems() -> [String : NSCoding]? {
		return clientConfig.storableTokenItems()
	}
	
	public override func forgetClient() {
		super.forgetClient()
		clientConfig.forgetCredentials()
	}
	
	public override func forgetTokens() {
		super.forgetTokens()
		clientConfig.forgetTokens()
	}
	
	
	// MARK: - Authorization
	
	/**
	Use this method, together with `authConfig`, to obtain an access token.
 
	This method will first check if the client already has an unexpired access token (possibly from the keychain), if not and it's able to
	use a refresh token it will try to use the refresh token. If this fails it will check whether the client has a client_id and show the
	authorize screen if you have `authConfig` set up sufficiently. If `authConfig` is not set up sufficiently this method will end up calling the
	`onFailure` callback. If client_id is not set but a "registration_uri" has been provided, a dynamic client registration will be
	attempted and if it succees, an access token will be requested.
	*/
	public func authorize(params params: OAuth2StringDict? = nil, autoDismiss: Bool = true) {
		tryToObtainAccessTokenIfNeeded() { success in
			if success {
				self.didAuthorize(OAuth2JSON())
			}
			else {
				self.registerClientIfNeeded() { error in
					if let error = error {
						self.didFail(error)
					}
					else {
						if self.authConfig.authorizeEmbedded {
							if !self.authorizeEmbeddedWith(self.authConfig, params: params, autoDismiss: autoDismiss) {
								self.didFail(nil == self.authConfig.authorizeContext ? OAuth2Error.NoAuthorizationContext : OAuth2Error.InvalidAuthorizationContext)
							}
						}
						else {
							if !self.openAuthorizeURLInBrowser(params) {
								fatalError("Cannot open authorize URL")
							}
						}
					}
				}
			}
		}
	}
	
	/**
	If the instance has an accessToken, checks if its expiry time has not yet passed. If we don't have an expiry date we assume the token
	is still valid.
	*/
	public func hasUnexpiredAccessToken() -> Bool {
		if let access = accessToken where !access.isEmpty {
			if let expiry = accessTokenExpiry {
				return expiry == expiry.laterDate(NSDate())
			}
			return clientConfig.accessTokenAssumeUnexpired
		}
		return false
	}
	
	/**
	Indicates, in the callback, whether the client has been able to obtain an access token that is likely to still
	work (but there is no guarantee).
	
	- parameter callback: The callback to call once the client knows whether it has an access token or not
	*/
	func tryToObtainAccessTokenIfNeeded(callback: ((success: Bool) -> Void)) {
		if hasUnexpiredAccessToken() {
			callback(success: true)
		}
		else {
			logIfVerbose("No access token, maybe I can refresh")
			doRefreshToken({ successParams, error in
				if nil != successParams {
					callback(success: true)
				}
				else {
					if let err = error {
						self.logIfVerbose("\(err)")
					}
					callback(success: false)
				}
			})
		}
	}
	
	/**
	Constructs an authorize URL with the given parameters.
	
	It is possible to use the `params` dictionary to override internally generated URL parameters, use it wisely.
	Subclasses generally provide shortcut methods to receive an appropriate authorize (or token) URL.
	
	- parameter redirect:     The redirect URI string to supply. If it is nil, the first value of the settings' `redirect_uris` entries is
	                          used. Must be present in the end!
	- parameter params:       Any additional parameters as dictionary with string keys and values that will be added to the query part
	- parameter asTokenURL:   Whether this will go to the token_uri endpoint, not the authorize_uri
	- returns:                NSURL to be used to start or continue the OAuth dance
	*/
	func authorizeURLWithParams(params: OAuth2StringDict, asTokenURL: Bool = false) throws -> NSURL {
		
		// compose URL base
		let base = asTokenURL ? (clientConfig.tokenURL ?? clientConfig.authorizeURL) : clientConfig.authorizeURL
		let comp = NSURLComponents(URL: base, resolvingAgainstBaseURL: true)
		if nil == comp || "https" != comp!.scheme {
			throw OAuth2Error.NotUsingTLS
		}
		
		// compose the URL query component
		comp!.percentEncodedQuery = OAuth2.queryStringFor(params)
		
		if let final = comp!.URL {
			logIfVerbose("Authorizing against \(final.description)")
			return final
		}
		throw OAuth2Error.Generic("Failed to create authorize URL from components: \(comp)")
	}
	
	/**
	Most convenient method if you want the authorize URL to be created as defined in your settings dictionary.
	
	- parameter params: Optional, additional URL params to supply to the request
	- returns: NSURL to be used to start the OAuth dance
	*/
	public func authorizeURL(params: OAuth2StringDict? = nil) throws -> NSURL {
		return try authorizeURLWithRedirect(nil, scope: nil, params: params)
	}
	
	/**
	Convenience method to be overridden by and used from subclasses.
	
	- parameter redirect:  The redirect URI string to supply. If it is nil, the first value of the settings' `redirect_uris` entries is
	                       used. Must be present in the end!
	- parameter scope:     The scope to request
	- parameter params:    Any additional parameters as dictionary with string keys and values that will be added to the
	query part
	- returns: NSURL to be used to start the OAuth dance
	*/
	public func authorizeURLWithRedirect(redirect: String?, scope: String?, params: OAuth2StringDict?) throws -> NSURL {
		guard let redirect = (redirect ?? clientConfig.redirect) else {
			throw OAuth2Error.NoRedirectURL
		}
		guard let clientId = clientId where !clientId.isEmpty else {
			throw OAuth2Error.NoClientId
		}
		var prms = params ?? OAuth2StringDict()
		prms["redirect_uri"] = redirect
		prms["client_id"] = clientId
		prms["state"] = context.state
		if let scope = scope ?? clientConfig.scope {
			prms["scope"] = scope
		}
		if let responseType = self.dynamicType.responseType {
			prms["response_type"] = responseType
		}
		context.redirectURL = redirect
		return try authorizeURLWithParams(prms, asTokenURL: false)
	}
	
	/**
	Subclasses override this method to extract information from the supplied redirect URL.
	*/
	public func handleRedirectURL(redirect: NSURL) throws {
		throw OAuth2Error.Generic("Abstract class use")
	}
	
	
	// MARK: - Refresh Token
	
	/**
	Generate the URL to be used for the token request when we have a refresh token.
	
	This will set "grant_type" to "refresh_token", add the refresh token, then forward to `authorizeURLWithParams()` to fill the remaining
	parameters.
	*/
	func tokenURLWithRefreshToken(redirect: String?, refreshToken: String, params: OAuth2StringDict? = nil) throws -> NSURL {
		var urlParams = params ?? OAuth2StringDict()
		urlParams["grant_type"] = "refresh_token"
		urlParams["refresh_token"] = clientConfig.refreshToken
		if let secret = clientConfig.clientSecret where authConfig.secretInBody {
			urlParams["client_secret"] = secret
		}
		return try authorizeURLWithParams(urlParams, asTokenURL: true)
	}
	
	/**
	Create a request for token refresh.
	*/
	func tokenRequestWithRefreshToken(refreshToken: String) throws -> NSMutableURLRequest {
		let url = try tokenURLWithRefreshToken(clientConfig.redirect, refreshToken: refreshToken)
		return try tokenRequestWithURL(url)
	}
	
	/**
	If there is a refresh token, use it to receive a fresh access token.
	
	- parameter callback: The callback to call after the refresh token exchange has finished
	*/
	public func doRefreshToken(callback: ((successParams: OAuth2JSON?, error: ErrorType?) -> Void)) {
		guard let refresh = clientConfig.refreshToken where !refresh.isEmpty else {
			callback(successParams: nil, error: OAuth2Error.NoRefreshToken)
			return
		}
		
		do {
			let post = try tokenRequestWithRefreshToken(refresh)
			logIfVerbose("Using refresh token to receive access token from \(post.URL?.description ?? "nil")")
			
			performRequest(post) { data, status, error in
				if let data = data {
					do {
						let json = try self.parseRefreshTokenResponse(data)
						if status < 400 {
							self.logIfVerbose("Did use refresh token for access token [\(nil != self.clientConfig.accessToken)]")
							callback(successParams: json, error: nil)
						}
						else {
							throw OAuth2Error.Generic("\(status)")
						}
					}
					catch let err {
						self.logIfVerbose("Error parsing refreshed access token: \(err)")
						callback(successParams: nil, error: err)
					}
				}
				else {
					callback(successParams: nil, error: error ?? OAuth2Error.NoDataInResponse)
				}
			}
		}
		catch let err {
			callback(successParams: nil, error: err)
		}
	}
	
	
	// MARK: - Registration
	
	/**
	Returns immediately if the receiver's `clientId` is nil (with error = nil) or if there is no registration URL (with error). Otherwise
	instantiates `OAuth2DynReg` to attempt client registration.
	
	- parameter callback: The callback to call; error is nil on success, otherwise contains the error encountered
	*/
	func registerClientIfNeeded(callback: ((error: ErrorType?) -> Void)) {
		if nil != clientId {
			callback(error: nil)
		}
		else if nil != clientConfig.registrationURL {
			let dynreg = OAuth2DynReg()
			dynreg.verbose = verbose
			dynreg.registerClient(self) { json, error in
				callback(error: error)
			}
		}
		else {
			callback(error: OAuth2Error.NoRegistrationURL)
		}
	}
	
	
	// MARK: - Callbacks
	
	/**
	Internally used on success. Calls the `onAuthorize` and `afterAuthorizeOrFailure` callbacks on the main thread.
	*/
	func didAuthorize(parameters: OAuth2JSON) {
		if useKeychain {
			storeTokensToKeychain()
		}
		
		callOnMainThread() {
			self.onAuthorize?(parameters: parameters)
			self.internalAfterAuthorizeOrFailure?(wasFailure: false, error: nil)
			self.afterAuthorizeOrFailure?(wasFailure: false, error: nil)
		}
	}
	
	/**
	Internally used on error. Calls the `onFailure` and `afterAuthorizeOrFailure` callbacks on the main thread.
	*/
	func didFail(error: ErrorType?) {
		if let err = error {
			logIfVerbose("\(err)")
		}
		callOnMainThread() {
			self.onFailure?(error: error)
			self.internalAfterAuthorizeOrFailure?(wasFailure: true, error: error)
			self.afterAuthorizeOrFailure?(wasFailure: true, error: error)
		}
	}
	
	
	// MARK: - Requests
	
	/**
	Return an OAuth2Request, a NSMutableURLRequest subclass, that has already been signed and can be used against
	your OAuth2 endpoint.
	
	This method prefers cached data and specifies a timeout interval of 20 seconds.
	
	- parameter forURL: The URL to create a request for
	- returns: OAuth2Request for the given URL
	*/
	public func request(forURL url: NSURL) -> OAuth2Request {
		return OAuth2Request(URL: url, oauth: self, cachePolicy: .ReturnCacheDataElseLoad, timeoutInterval: 20)
	}
	
	
	// MARK: - Utilities
	
	/**
	    Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	 */
	func tokenRequestWithURL(url: NSURL) throws -> NSMutableURLRequest {
		guard let clientId = clientId where !clientId.isEmpty else {
			throw OAuth2Error.NoClientId
		}
		
		let comp = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
		assert(comp != nil, "It seems NSURLComponents cannot parse \(url)");
		let body = comp!.percentEncodedQuery
		comp!.query = nil
		
		let req = NSMutableURLRequest(URL: comp!.URL!)
		req.HTTPMethod = "POST"
		req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
		req.HTTPBody = body?.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		
		// add Authorization header if we have a client secret (even if it's empty)
		if let secret = clientSecret where !authConfig.secretInBody {
			logIfVerbose("Adding “Authorization” header as “Basic client-key:client-secret”")
			let pw = "\(clientId.wwwFormURLEncodedString):\(secret.wwwFormURLEncodedString)"
			if let utf8 = pw.dataUsingEncoding(NSUTF8StringEncoding) {
				req.setValue("Basic \(utf8.base64EncodedStringWithOptions([]))", forHTTPHeaderField: "Authorization")
			}
			else {
				logIfVerbose("ERROR: for some reason failed to base-64 encode the client-key:client-secret combo")
			}
		}
		return req
	}
	
	
	// MARK: - Response Parsing
	
	/**
	Parse response data returned while exchanging the code for a token.
	
	This method extracts token data and fills the receiver's properties accordingly. If the response contains an "error" key, will parse the
	error and throw it.
	
	- parameter data: NSData returned from the call
	- returns: An OAuth2JSON instance with token data; may contain additional information
	*/
	func parseAccessTokenResponse(data: NSData) throws -> OAuth2JSON {
		let dict = try parseJSON(data)
		return try parseAccessTokenResponse(dict)
	}
	
	/**
	Parse response data returned while exchanging the code for a token.
	
	This method extracts token data and fills the receiver's properties accordingly. If the response contains an "error" key, will parse the
	error and throw it. The method is final to ensure correct order of error parsing and not parsing the response if an error happens. This
	is not possible in overrides. Instead, override the various `assureXy(dict:)` methods.
	
	- parameter json: Dictionary data parsed from the response
	- returns: An OAuth2JSON instance with token data; may contain additional information
	*/
	final func parseAccessTokenResponse(dict: OAuth2JSON) throws -> OAuth2JSON {
		try assureNoErrorInResponse(dict)
		try assureMatchesState(dict)
		try assureCorrectBearerType(dict)
		
		clientConfig.updateFromResponse(dict)
		return dict
	}
	
	/**
	Parse response data returned while using a refresh token.
	
	This method extracts token data and fills the receiver's properties accordingly. If the response contains an "error" key, will parse the
	error and throw it.
	
	- parameter data: NSData returned from the call
	- returns: An OAuth2JSON instance with token data; may contain additional information
	*/
	func parseRefreshTokenResponse(data: NSData) throws -> OAuth2JSON {
		let dict = try parseJSON(data)
		return try parseRefreshTokenResponse(dict)
	}
	
	/**
	Parse response data returned while using a refresh token.
	
	This method extracts token data and fills the receiver's properties accordingly. If the response contains an "error" key, will parse the
	error and throw it.
	
	- parameter json: Dictionary data parsed from the response
	- returns: An OAuth2JSON instance with token data; may contain additional information
	*/
	func parseRefreshTokenResponse(dict: OAuth2JSON) throws -> OAuth2JSON {
		try assureNoErrorInResponse(dict)
		try assureCorrectBearerType(dict)
		
		clientConfig.updateFromResponse(dict)
		return dict
	}
	
	/**
	This method does nothing in the base class. Implicit and code grant flows override it to check state.
	*/
	func assureMatchesState(params: OAuth2JSON) throws {
	}
	
	/**
	Throws unless "token_type" is "bearer" (case-insensitive).
	*/
	func assureCorrectBearerType(params: OAuth2JSON) throws {
		if let tokType = params["token_type"] as? String {
			if "bearer" == tokType.lowercaseString {
				return
			}
			throw OAuth2Error.UnsupportedTokenType("Only “bearer” token is supported, but received “\(tokType)”")
		}
		throw OAuth2Error.NoTokenType
	}
}


class OAuth2ContextStore {
	
	/// Currently used redirect_url.
	var redirectURL: String?
	
	internal(set) var _state = ""
	
	/** The state sent to the server when requesting a token.
	
	We internally generate a UUID and use the first 8 chars if `_state` is empty.
	*/
	var state: String {
		if _state.isEmpty {
			_state = NSUUID().UUIDString
			_state = _state[_state.startIndex..<_state.startIndex.advancedBy(8)]		// only use the first 8 chars, should be enough
		}
		return _state
	}
	
	func enforceState(state: String) {
		_state = state
	}
	
	func matchesState(state: String?) -> Bool {
		if let st = state {
			return st == _state
		}
		return false
	}
	
	func resetState() {
		_state = ""
	}
}

