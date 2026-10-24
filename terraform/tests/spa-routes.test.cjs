const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const vm = require('node:vm')

const source = fs.readFileSync(path.join(__dirname, '../modules/frontend/spa-routes.js'), 'utf8')
const handler = vm.runInNewContext(`${source}\nhandler`)

test('React routes serve index.html', () => {
  for (const uri of ['/', '/login', '/app/beneficiarios', '/app/transferencias/123']) {
    const request = { uri }
    assert.equal(handler({ request }).uri, '/index.html')
  }
})

test('static assets keep their requested path', () => {
  for (const uri of ['/assets/app-123.js', '/favicon.ico', '/assets/logo.svg']) {
    const request = { uri }
    assert.equal(handler({ request }).uri, uri)
  }
})
