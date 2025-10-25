from math import sqrt

struct PointTag(Copyable):
    pass


struct VectorTag(Copyable):
    pass


struct ColourTag(Copyable):
    pass


fn is_same[T: AnyType, U: AnyType](t: T, u: U) -> Bool:
    return False

fn is_same[T: AnyType](t: T, tt: T) -> Bool:
    return True

alias Point[T: DType] = Vec3[T, PointTag]
alias Vector[T: DType] = Vec3[T, VectorTag]
alias Colour[T: DType] = Vec3[T, ColourTag]

@register_passable("trivial")
struct Vec3[T: DType, Tag: AnyType]:
    alias Simd = SIMD[T, 4]
    var data: Self.Simd

    fn __init__(out self, other: Self):
        self.data = other.data

    fn __init__(out self, other: Self.Simd):
        self.data = other

    fn __init__(out self, x: Scalar[T], y: Scalar[T], z: Scalar[T]):
        self.data = Self.Simd(x, y, z, 0)

    fn x(self) -> Scalar[T]:
        return self.data[0]

    fn y(self) -> Scalar[T]:
        return self.data[1]

    fn z(self) -> Scalar[T]:
        return self.data[2]

    fn __add__(self: Vector[T], rhs: Vector[T]) -> Vector[T]:
        return Vector[T](self.data + rhs.data)

    fn __add__(self: Point[T], rhs: Vector[T]) -> Point[T]:
        return Point[T](self.data + rhs.data)

    fn __radd__(self: Point[T], lhs: Vector[T]) -> Vector[T]:
        return Vector[T](lhs.data + self.data)

    fn __add__(self: Colour[T], rhs: Colour[T]) -> Colour[T]:
        return Colour[T](self.data + rhs.data)

    fn __sub__(self: Vector[T], rhs: Vector[T]) -> Vector[T]:
        return Vector[T](self.data - rhs.data)

    fn __sub__(self: Point[T], rhs: Point[T]) -> Vector[T]:
        return Vector[T](self.data - rhs.data)

    fn __sub__(self: Point[T], rhs: Vector[T]) -> Vector[T]:
        return Vector[T](self.data - rhs.data)

    fn __rsub__(self: Point[T], lhs: Vector[T]) -> Vector[T]:
        return Vector[T](lhs.data - self.data)

    fn __mul__(self, rhs: Scalar[T]) -> Self:
        return Self(self.data * rhs)

    fn __rmul__(self, lhs: Scalar[T]) -> Self:
        return Self(lhs * self.data)

    fn __truediv__(self, rhs: Scalar[T]) -> Self:
        return Self(self.data / rhs)

    fn __neg__(self) -> Self:
        return Self(-self.data)

    fn len(self) -> Scalar[T]:
        return sqrt((self.data * self.data).reduce_add())

    fn len_sq(self) -> Scalar[T]:
        return (self.data * self.data).reduce_add()

fn dot[T: DType](lhs: Vector[T], rhs: Vector[T]) -> Scalar[T]:
    return (lhs.data * rhs.data).reduce_add()

@register_passable("trivial")
struct Ray[T: DType]:
    var origin: Point[T]
    var dir: Vector[T]

    fn __init__(out self, o: Point[T], d: Vector[T]):
        self.origin = o
        self.dir = d

    fn at(self, t: Scalar[T]) -> Point[T]:
        return self.origin + t * self.dir


def write(name: String, h: Int, w: Int, data: List[InlineArray[UInt8, 3]]):
    header = "P3\n{} {}\n{}\n".format(w, h, 255)
    with open(name, "w") as f:
        f.write(header)
        for e in data:
            f.write("{} {} {}\n".format(e[0], e[1], e[2]))

fn unit[T: DType](v: Vector[T]) -> Vector[T]:
    return v / v.len()

fn sky[T: DType](ray: Ray[T]) -> Colour[T]:
    t = hit(Point[T](0, 0, -1), 0.5, ray)
    if t > 0:
        norm = unit[T](ray.at(t) - Vector[T](0, 0, -1))
        return 0.5 * Colour[T](norm.x() + 1, norm.y() + 1, norm.z() + 1)
    var unit_dir: Vector[T] = unit(ray.dir)
    a = 0.5 * (unit_dir.y() + 1.0)
    return (1.0 - a) * Colour[T](1.0, 1.0, 1.0) + a * Colour[T](0.5, 0.7, 1.0)

fn convert[T: DType](colour: Colour[T]) -> InlineArray[UInt8, 3]:
    ret = InlineArray[UInt8, 3](0)
    ret[0] = Int(colour.x() * 255.99)
    ret[1] = Int(colour.y() * 255.99)
    ret[2] = Int(colour.z() * 255.99)
    return ret

fn hit[T: DType](centre: Point[T], radius: Scalar[T], ray: Ray[T]) -> Scalar[T]:
    oc = centre - ray.origin
    a = ray.dir.len_sq()
    h = dot(ray.dir, oc)
    c = oc.len_sq() - radius * radius
    disc = h * h - a * c
    return -1.0 if disc < 0 else (h - sqrt(disc)) / a

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
    camera_centre = Point[DType.float32](0.0, 0.0, 0.0)
    viewport_u = Vector[DType.float32](viewport_width, 0.0, 0.0)
    viewport_v = Vector[DType.float32](0.0, -viewport_height, 0.0)
    pixel_delta_u = viewport_u / image_width
    pixel_delta_v = viewport_v / image_height
    viewport_upper_left = camera_centre - Vector[DType.float32](0.0, 0.0, focal_length)
        - viewport_u / 2.0 - viewport_v / 2.0
    pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v)

    for j in range(image_height):
        for i in range(image_width):
            pixel_centre = pixel00_loc +
                (i * pixel_delta_u) + (j * pixel_delta_v)
            ray_direction = pixel_centre - camera_centre
            r = Ray[DType.float32](camera_centre, ray_direction)
            img.append(convert(sky(r)))
    write("file.ppm", image_height, image_width, img)
