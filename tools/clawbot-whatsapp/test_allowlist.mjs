import assert from 'node:assert/strict';
import {
  createConfig,
  getBasicCommandResponse,
  isAuthorizedChat,
  normalizePhone,
} from './clawbot_core.mjs';

const config = createConfig({
  CLAWBOT_OWNER_PHONE: '5492996209136',
  CLAWBOT_ALLOWED_PHONES: '5492996209136',
  CLAWBOT_ALLOW_GROUPS: 'false',
  CLAWBOT_REQUIRE_PREFIX: 'false',
  CLAWBOT_COMMAND_PREFIX: '',
  BITFLOW_DEMO_URL: 'https://example.test/demo',
});

assert.equal(normalizePhone('2996209136'), '5492996209136');
assert.equal(normalizePhone('+5492996209136'), '5492996209136');
assert.equal(
  isAuthorizedChat({ from: '5492996209136@c.us', isGroup: false }, config).allowed,
  true,
);
assert.equal(
  isAuthorizedChat({ from: '2996209136@c.us', isGroup: false }, config).allowed,
  true,
);
assert.equal(
  isAuthorizedChat({ from: '5491111111111@c.us', isGroup: false }, config).allowed,
  false,
);
assert.equal(
  isAuthorizedChat({ from: '120363000000000000@g.us', author: '5492996209136@c.us', isGroup: true }, config).allowed,
  false,
);
assert.equal(getBasicCommandResponse('ping', config), 'pong');
assert.match(getBasicCommandResponse('ayuda', config), /Comandos disponibles/);

console.log('allowlist and command tests passed');
