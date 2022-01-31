const std = @import("std");
const ray = @import("ray.zig");
const camera = @import("camera.zig");
const config = @import("config.zig");
const sphere = @import("sphere.zig");
const vector = @import("vector.zig");
const material = @import("material.zig");

const Vec3 = config.Vec3;

pub const Hit = struct {
    object_idx: ?usize = undefined,
    ray_scale_factor: f64 = std.math.f64_max,
};

pub const Scene = struct {
    camera: *camera.Camera,
    lights: std.ArrayList(usize),
    objects: std.ArrayList(sphere.Sphere),

    pub fn intersect(self: *Scene, cur_ray: ray.Ray) Hit {
        var hit: Hit = .{};
        var ray_scale_factor: f64 = undefined;
        for (self.objects.items) |cur_sphere, idx| {
            ray_scale_factor = cur_sphere.computeRaySphereHit(cur_ray);
            if (ray_scale_factor > 0.0 and ray_scale_factor < hit.ray_scale_factor) {
                hit.ray_scale_factor = ray_scale_factor;
                hit.object_idx = idx;
            }
        }
        return hit;
    }

    pub fn collectLights(self: *Scene) !void {
        for (self.objects.items) |object, light_idx| {
            if (object.isLight()) {
                try self.lights.append(light_idx);
            }
        }
    }
};

pub fn sampleLights(scene: *Scene, hit_point: Vec3, normal: Vec3, ray_direction: Vec3, cur_material: *const material.Material) Vec3 {
    var color = config.ZERO_VECTOR;
    for (scene.lights.items) |light_idx| {
        const light = scene.objects.items[light_idx];
        var hit_point_to_light_center = light.center - hit_point;
        const distance_to_light_sqrd = vector.dot_product(hit_point_to_light_center, hit_point_to_light_center);
        hit_point_to_light_center = vector.normalize(hit_point_to_light_center);
        var cos_theta = vector.dot_product(normal, hit_point_to_light_center);
        var shadow_ray = ray.Ray{ .origin = hit_point, .direction = hit_point_to_light_center };
        var shadow_ray_hit = scene.intersect(shadow_ray);
        if (shadow_ray_hit.object_idx) |shadow_idx| {
            if (shadow_idx == light_idx) {
                if (cos_theta > 0.0) {
                    const sin_alpha_max_sqrd = light.radius * light.radius / distance_to_light_sqrd;
                    const cos_alpha_max = @sqrt(1.0 - sin_alpha_max_sqrd);
                    const omega = 2.0 * (1.0 - cos_alpha_max);
                    cos_theta *= omega;
                    color += cur_material.diffuse * light.material.emissive * @splat(config.SCENE_DIMS, cos_theta);
                }
                if (cur_material.material_type == material.MaterialType.GLOSSY or cur_material.material_type == material.MaterialType.MIRROR) {
                    const reflected_direction = vector.reflect(hit_point_to_light_center, normal);
                    cos_theta = -vector.dot_product(reflected_direction, ray_direction);
                    if (cos_theta > 0.0) {
                        const specular_color = cur_material.specular * @splat(config.SCENE_DIMS, std.math.pow(f64, cos_theta, cur_material.specular_exponent));
                        color += specular_color;
                    }
                }
            }
        }
    }
    return color;
}
