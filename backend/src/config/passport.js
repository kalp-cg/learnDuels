const passport = require('passport');
const { prisma } = require('./db');
const config = require('./env');

passport.serializeUser((user, done) => {
  done(null, user.id);
});

passport.deserializeUser(async (id, done) => {
  try {
    const user = await prisma.user.findUnique({ where: { id } });
    done(null, user);
  } catch (error) {
    done(error, null);
  }
});

// OAuth strategies removed - use email/password authentication only



module.exports = passport;
