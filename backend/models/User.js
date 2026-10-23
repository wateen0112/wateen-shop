const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

// مستخدم المتجر — يحدد الأدمن صلاحياته
const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true, lowercase: true, trim: true },
  passwordHash: { type: String, required: true },
  name: { type: String, default: '' },
  role: { type: String, enum: ['admin', 'user'], default: 'user' },
  permissions: { type: [String], default: [] },
  active: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now },
});

userSchema.methods.setPassword = async function (plain) {
  this.passwordHash = await bcrypt.hash(plain, 10);
};

userSchema.methods.checkPassword = function (plain) {
  return bcrypt.compare(plain, this.passwordHash);
};

//Representation بدون كلمة المرور
userSchema.methods.toSafe = function () {
  return {
    _id: this._id,
    username: this.username,
    name: this.name,
    role: this.role,
    permissions: this.role === 'admin' ? ['*'] : this.permissions,
    active: this.active,
    createdAt: this.createdAt,
  };
};

userSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    delete ret.passwordHash;
    return ret;
  },
});

module.exports = mongoose.model('User', userSchema);
