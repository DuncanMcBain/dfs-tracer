from math import Ceilable, CeilDivable, Floorable, Truncable, sqrt
from builtin.device_passable import DevicePassable
from builtin.math import Absable, Powable

struct PointTag(Copyable):
    pass


struct VectorTag(Copyable):
    pass


struct ColourTag(Copyable):
    pass

trait Negatable:
    fn __neg__(self) -> Self:
        ...

trait Multiplyable:
    fn __mul__(self, other: Self) -> Self:
        ...

alias Point = Vec3[PointTag]
alias Vector = Vec3[VectorTag]
# extending this somehow with r() g() b() functions would be nice but meh
alias Colour = Vec3[ColourTag]

@register_passable("trivial")
struct Vec3[#T:
    #Absable &
    #Comparable &
    #Copyable &
    #Defaultable &
    #DevicePassable &
    #Floorable &
    #Intable &
    #Movable &
    #Powable &
    #Truncable,
    Tag: AnyType]():

    #var data: SIMD[T, 4] # we'd like this to be the type but I can't match
    # the requirements of the DType parameter for the SIMD type, because DType
    # is an object not a trait? If it were a trait I could match it
    alias Simd = SIMD[DType.float32, 4]
    var data: Self.Simd

    fn __init__(out self, other: Self):
        self.data = other.data

    fn __init__(out self, other: Self.Simd):
        self.data = other

    fn __init__(out self, x: Float32, y: Float32, z: Float32):
        self.data = Self.Simd(x, y, z, 0)

    fn x(self) -> Float32:
        return self.data[0]

    fn y(self) -> Float32:
        return self.data[1]

    fn z(self) -> Float32:
        return self.data[2]

    fn __add__(self, lhs: Vector) -> Self:
        return Self(self.data + lhs.data)

    fn __add__(self, lhs: Colour) -> Self:
        return Self(self.data + lhs.data)

    fn __radd__(self, rhs: Vector) -> Self:
        return Self(self.data + rhs.data)

    fn __sub__(self, lhs: Point) -> Vector:
        return Vector(self.data - lhs.data)

    fn __sub__(self, lhs: Vector) -> Vector:
        return Vector(self.data - lhs.data)

    fn __mul__(self, lhs: Float32) -> Self:
        return Self(self.data * lhs)

    fn __rmul__(self, rhs: Float32) -> Self:
        return Self(self.data * rhs)

    fn __truediv__(self, lhs: Float32) -> Self:
        return Self(self.data / lhs)

    fn __neg__(self) -> Self:
        return Self(-self.data)

    fn len(self) -> Float32:
        return sqrt((self.data * self.data).reduce_add())

fn dot(lhs: Vector, rhs: Vector) -> Float32:
    return (lhs.data * rhs.data).reduce_add()

struct Ray:
    var origin: Point
    var dir: Vector

    fn __init__(out self, o: Point, d: Vector):
        self.origin = o
        self.dir = d

    fn at(self, t: Float32) -> Point:
        return self.origin + t * self.dir


def write(name: String, h: Int, w: Int, data: List[InlineArray[UInt8, 3]]):
    header = "P3\n{} {}\n{}\n".format(w, h, 255)
    with open(name, "w") as f:
        f.write(header)
        for e in data:
            f.write("{} {} {}\n".format(e[0], e[1], e[2]))

fn unit(v: Vector) -> Vector:
    return v / v.len()

fn sky(ray: Ray) -> Colour:
    if hit(Point(0, 0, -1), 0.5, ray):
        return Colour(1, 0, 0)
    var unit_dir: Vector = unit(ray.dir)
    a = 0.5 * (unit_dir.y() + 1.0)
    return (1.0 - a) * Colour(1.0, 1.0, 1.0) + a * Colour(0.5, 0.7, 1.0)

fn convert(colour: Colour) -> InlineArray[UInt8, 3]:
    ret = InlineArray[UInt8, 3](0)
    ret[0] = Int(colour.x() * 255.99)
    ret[1] = Int(colour.y() * 255.99)
    ret[2] = Int(colour.z() * 255.99)
    return ret

fn hit(centre: Point, radius: Float32, r: Ray) -> Bool:
    oc = centre - r.origin
    a = dot(r.dir, r.dir)
    b = -2.0 * dot(r.dir, oc)
    c = dot(oc, oc) - radius * radius
    disc = b * b - 4 * a * c
    return disc > 0

def main():
    print("test")
    img = List[InlineArray[UInt8, 3]]()

    var aspect_ratio: Float32 = 16.0 / 9.0
    var image_width: Int = 400
    var image_height: Int = Int(image_width / aspect_ratio)
    image_height = 1 if image_height < 1 else image_height
    var viewport_height: Float32 = 2.0
    viewport_width = viewport_height * image_width / image_height
    var focal_length: Float32 = 1.0
    camera_centre = Point(0.0, 0.0, 0.0)
    viewport_u = Vector(viewport_width, 0.0, 0.0)
    viewport_v = Vector(0.0, -viewport_height, 0.0)
    pixel_delta_u = viewport_u / image_width
    pixel_delta_v = viewport_v / image_height
    viewport_upper_left = camera_centre - Vector(0.0, 0.0, focal_length)
        - viewport_u / 2.0 - viewport_v / 2.0
    pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v)

    for j in range(image_height):
        for i in range(image_width):
            pixel_centre = pixel00_loc +
                (i * pixel_delta_u) + (j * pixel_delta_v)
            ray_direction = pixel_centre - camera_centre
            r = Ray(camera_centre, ray_direction)
            img.append(convert(sky(r)))
    write("file.ppm", image_height, image_width, img)
