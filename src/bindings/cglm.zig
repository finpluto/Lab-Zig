const cglm_binding = @import("cglm-binding");

pub const Vec3 = [3]f32;

pub fn vec3Add(a: *const Vec3, b: *const Vec3, dst: *Vec3) void {
    cglm_binding.glm_vec3_add(@constCast(a), @constCast(b), dst);
}

pub fn vec3Sub(a: *const Vec3, b: *const Vec3, dst: *Vec3) void {
    cglm_binding.glm_vec3_sub(@constCast(a), @constCast(b), dst);
}

pub fn vec3Scale(v: *const Vec3, s: f32, dst: *Vec3) void {
    cglm_binding.glm_vec3_scale(@constCast(v), s, dst);
}

pub fn vec3DivScalar(v: *const Vec3, s: f32, dst: *Vec3) void {
    cglm_binding.glm_vec3_divs(@constCast(v), s, dst);
}

pub fn clamp(arg_val: f32, min_val: f32, max_val: f32) f32 {
    return cglm_binding.glm_clamp(arg_val, min_val, max_val);
}
