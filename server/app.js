// CommonJS on purpose (ltijs examples use it)
const path = require('path')
const fs = require('fs')
const dotenv = require('dotenv')
dotenv.config()

const LtiProvider = require('ltijs').Provider
const helmet = require('helmet')
const morgan = require('morgan')
const rateLimit = require('express-rate-limit')
const express = require('express')

const PORT = process.env.PORT || 3000

// Create logs directory if it doesn't exist
const logsDir = path.join(__dirname, '../logs/app')
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true })
}

// Setup logging
const accessLogStream = fs.createWriteStream(
  path.join(logsDir, 'access.log'), 
  { flags: 'a' }
)

const errorLogStream = fs.createWriteStream(
  path.join(logsDir, 'error.log'), 
  { flags: 'a' }
)

// Custom console logging to file
const originalConsoleLog = console.log
const originalConsoleError = console.error

console.log = (...args) => {
  const timestamp = new Date().toISOString()
  const message = `[${timestamp}] INFO: ${args.join(' ')}\n`
  fs.appendFileSync(path.join(logsDir, 'app.log'), message)
  originalConsoleLog(...args)
}

console.error = (...args) => {
  const timestamp = new Date().toISOString()
  const message = `[${timestamp}] ERROR: ${args.join(' ')}\n`
  fs.appendFileSync(path.join(logsDir, 'error.log'), message)
  originalConsoleError(...args)
}

// 1) init ltijs - using environment variable for mongo URI
const mongoUri = process.env.MONGO_URI || `mongodb+srv://chhotu22:ioufDLeFolNHv4TR@lti.wfvxszi.mongodb.net/ltijs?retryWrites=true&w=majority&appName=lti`

const lti = new LtiProvider(
  process.env.COOKIE_KEY || 'supersecret',
  { url: mongoUri },
  {
    appRoute: '/',
    loginRoute: '/login',
    keysetRoute: '/keys',
    cookies: {
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'None'
    },
    staticPath: path.join(__dirname, '../public'),
    devMode: process.env.NODE_ENV !== 'production',
    dynRegRoute: '/register',
    dynReg: {
      url: 'https://lti.csbasics.in/',
      name: 'Visual Search Game',
      logo: 'https://imgs.search.brave.com/Nh8VoS-LeggCpHsK1WyrJ93y5ZzhdvOHID1hEXXjp6Y/rs:fit:500:0:1:0/g:ce/aHR0cHM6Ly90My5m/dGNkbi5uZXQvanBn/LzAyLzQ3LzAwLzYy/LzM2MF9GXzI0NzAw/NjIzMl9RS2hJNlUy/RlByNDlrUEJBZ09C/a2tvWWhOQXBxbG5W/Mi5qcGc',
      description: 'Visual Search Game - Cognitive Psychology Experiment',
      redirectUris: ['https://lti.csbasics.in/launch'],
      autoActivate: true
    }
  }
)

// 2) after a successful launch, serve your static UI (the visual search game)
lti.onConnect((token, req, res) => {
  return res.sendFile(path.join(__dirname, '../public/index.html'))
})

// 3) deploy, then wire express middlewares & routes
lti.deploy({ port: PORT }).then(async () => {
  // register platforms from .env
  await require('./platform-registry')(lti)

  // harden Express
  lti.app.set('trust proxy', 1)
  
  // Setup access logging
  lti.app.use(morgan('combined', { stream: accessLogStream }))
  lti.app.use(morgan('combined')) // Also log to console
  
  lti.app.use(helmet({ 
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: false // Disable CSP to allow your game's inline scripts
  }))
  lti.app.use(rateLimit({ windowMs: 60_000, max: 120 }))
  lti.app.use(express.json())

  // allow only LMS to frame us
  const frameAncestors = (process.env.FRAME_ANCESTORS || '').trim()
  lti.app.use((req, res, next) => {
    if (frameAncestors) {
      res.setHeader('Content-Security-Policy', `frame-ancestors ${frameAncestors};`)
      res.setHeader('X-Frame-Options', 'ALLOW-FROM ' + frameAncestors.split(' ')[0])
    }
    next()
  })

  // static files (for your game assets)
  lti.app.use('/static', express.static(path.join(__dirname, '../public')))

  // Your existing grade endpoint adapted to the new structure
  lti.app.post('/api/grade', async (req, res) => {
    try {
      const token = res.locals.token
      if (!token) return res.status(401).json({ error: 'Not an LTI session' })

      const score = Number(req.body?.score ?? req.body?.grade ?? 100)
      const max = Number(req.body?.max ?? 10000) // Keep your 10000 max for reaction times
      const resourceLinkId =
        token.platformContext?.resource?.id ||
        token.platformContext?.resource?.resourceLink?.id

      console.log('Submitting grade:', { score, max, userId: token.user })

      // ensure a line item exists
      const items = await lti.Grade.getLineItems(token, { resourceLinkId, tag: 'visual-search' })
      const lineItem =
        items?.[0] ||
        (await lti.Grade.createLineItem(token, {
          label: 'Visual Search Game Score',
          scoreMaximum: max,
          resourceLinkId,
          tag: 'visual-search'
        }))

      const lineItemId = lineItem.id || lineItem

      await lti.Grade.submitScore(token, lineItemId, {
        userId: token.user,
        scoreGiven: score,
        scoreMaximum: max,
        activityProgress: 'Completed',
        gradingProgress: 'FullyGraded'
      })

      console.log('Grade submitted successfully')
      res.json({ ok: true })
    } catch (e) {
      console.error('Grade submission error:', e)
      res.status(500).json({ error: 'grade passback failed: ' + e.message })
    }
  })

  // Legacy grade endpoint for backward compatibility
  lti.app.post('/grade', async (req, res) => {
    try {
      const token = res.locals.token
      if (!token) return res.status(401).json({ error: 'Not an LTI session' })

      const score = req.body.grade
      const gradeObj = {
        userId: token.user,
        scoreGiven: score,
        scoreMaximum: 10000,
        activityProgress: 'Completed',
        gradingProgress: 'FullyGraded'
      }

      let lineItemId = token.platformContext?.endpoint?.lineitem
      if (!lineItemId) {
        const response = await lti.Grade.getLineItems(token, { resourceLinkId: true })
        const lineItems = response.lineItems
        if (lineItems.length === 0) {
          console.log('Creating new line item')
          const newLineItem = {
            scoreMaximum: 10000,
            label: 'Visual Search Game Score',
            tag: 'grade',
            resourceLinkId: token.platformContext.resource.id
          }
          const lineItem = await lti.Grade.createLineItem(token, newLineItem)
          lineItemId = lineItem.id
        } else {
          lineItemId = lineItems[0].id
        }
      }

      const responseGrade = await lti.Grade.submitScore(token, lineItemId, gradeObj)
      return res.send(responseGrade)
    } catch (err) {
      console.error('Legacy grade endpoint error:', err)
      return res.status(500).send({ err: err.message })
    }
  })

  console.log(`Visual Search Game LTI tool ready on :${PORT}`)
})

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err)
  process.exit(1)
})

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason)
  process.exit(1)
})
