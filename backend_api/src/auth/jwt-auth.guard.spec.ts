import { extractBearerToken } from './jwt-auth.guard.js';

describe('extractBearerToken', () => {
  it.each([
    ['Bearer abc.def.ghi', 'abc.def.ghi'],
    ['bearer abc.def.ghi', 'abc.def.ghi'],
    ['Bearer   abc.def.ghi  ', 'abc.def.ghi'],
  ])('reads %j', (header, token) => {
    expect(extractBearerToken(header)).toBe(token);
  });

  it.each([undefined, '', 'Bearer', 'Bearer ', 'Basic abc', 'abc.def.ghi', 'Bearer a b'])('rejects %j', (header) => {
    expect(extractBearerToken(header)).toBeNull();
  });
});
