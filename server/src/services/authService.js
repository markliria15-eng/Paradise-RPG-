const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { z } = require("zod");
const { v4: uuidv4 } = require("uuid");
const config = require("../config");
const accountRepo = require("../repositories/accountRepository");
const characterRepo = require("../repositories/characterRepository");

const registerSchema = z.object({
  username: z.string().min(3).max(32).regex(/^[a-zA-Z0-9_]+$/),
  email: z.string().email().max(120),
  password: z.string().min(6).max(72),
  characterName: z.string().min(3).max(32).regex(/^[a-zA-Z0-9_ ]+$/),
  className: z.enum(["Guerreiro", "Mago", "Arqueiro"])
});

const loginSchema = z.object({
  login: z.string().min(3).max(120).refine((value) => !/\s/.test(value)),
  password: z.string().min(6).max(72)
});

function parseOrFriendlyError(schema, payload, mode) {
  const result = schema.safeParse(payload);
  if (result.success) return result.data;
  const issue = result.error.issues[0];
  const field = issue ? String(issue.path[0] || "") : "";
  if (field === "email") {
    throw new Error("Erro: email invalido.");
  }
  if (field === "username" || field === "login") {
    throw new Error("Erro: nao pode colocar espaco em login.");
  }
  if (field === "password") {
    throw new Error("Erro: a senha precisa ter pelo menos 6 caracteres.");
  }
  if (field === "characterName") {
    throw new Error("Erro: nome do personagem invalido.");
  }
  if (field === "className") {
    throw new Error("Erro: escolha uma classe valida.");
  }
  throw new Error(mode === "register" ? "Erro: dados de registro invalidos." : "Erro: dados de login invalidos.");
}

function signToken(account) {
  const jti = uuidv4();
  const token = jwt.sign(
    {
      sub: String(account.id),
      username: account.username,
      vip: account.vip,
      premiumDays: account.premium_days,
      jti
    },
    config.jwtSecret,
    { expiresIn: config.jwtExpires }
  );
  return { token, jti };
}

async function register(payload) {
  const data = parseOrFriendlyError(registerSchema, payload, "register");
  const existsByEmail = await accountRepo.findByEmail(data.email);
  if (existsByEmail) {
    throw new Error("E-mail ja cadastrado.");
  }
  const existsByUser = await accountRepo.findByUsername(data.username);
  if (existsByUser) {
    throw new Error("Username ja cadastrado.");
  }
  const existingCharacter = await characterRepo.findByName(data.characterName);
  if (existingCharacter) {
    throw new Error("Nome de personagem ja em uso.");
  }

  const passwordHash = await bcrypt.hash(data.password, 12);
  const account = await accountRepo.createAccount({
    username: data.username,
    email: data.email,
    passwordHash
  });
  const character = await characterRepo.createCharacter({
    accountId: account.id,
    name: data.characterName,
    className: data.className
  });
  const { token, jti } = signToken(account);

  return {
    account: {
      id: account.id,
      username: account.username,
      email: account.email,
      vip: account.vip,
      premiumDays: account.premium_days
    },
    character,
    token,
    jti
  };
}

async function login(payload) {
  const data = parseOrFriendlyError(loginSchema, payload, "login");
  const login = data.login.trim();
  const account = login.includes("@")
    ? await accountRepo.findByEmail(login)
    : await accountRepo.findByUsername(login);
  if (!account) {
    throw new Error("Credenciais invalidas.");
  }
  if (account.banned) {
    throw new Error("Conta banida.");
  }
  const valid = await bcrypt.compare(data.password, account.password_hash);
  if (!valid) {
    throw new Error("Credenciais invalidas.");
  }
  await accountRepo.touchLastLogin(account.id);
  const characters = await characterRepo.listByAccount(account.id);
  const { token, jti } = signToken(account);
  return {
    account: {
      id: account.id,
      username: account.username,
      email: account.email,
      vip: account.vip,
      premiumDays: account.premium_days
    },
    characters,
    token,
    jti
  };
}

function verifyToken(token) {
  return jwt.verify(token, config.jwtSecret);
}

module.exports = {
  register,
  login,
  verifyToken
};
