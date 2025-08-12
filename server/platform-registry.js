module.exports = async function registerAll(lti) {
  const spec = (process.env.PLATFORMS || '').split(';').filter(Boolean)
  
  // If no platforms in env, skip registration (will use dynamic registration)
  if (spec.length === 0) {
    console.log('No platforms configured in .env - using dynamic registration only')
    return
  }

  for (const p of spec) {
    const [name, url, clientId, auth, token, jwks] = p.split(',')
    
    if (!name || !url || !clientId) {
      console.warn(`Skipping incomplete platform config: ${p}`)
      continue
    }

    try {
      // idempotent: register only once
      const exists = await lti.getPlatform(url)
      if (!exists) {
        await lti.registerPlatform({
          url, 
          name, 
          clientId,
          authenticationEndpoint: auth,
          accesstokenEndpoint: token,
          authConfig: { method: 'JWK_SET', key: jwks }
        })
        console.log(`Registered platform: ${name} (${url})`)
      } else {
        console.log(`Platform already registered: ${name} (${url})`)
      }
    } catch (error) {
      console.error(`Failed to register platform ${name}:`, error.message)
    }
  }
}
