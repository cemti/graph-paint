// (cx, dx, si, di)
void line(int x0, int y0, const int x1, const int y1)
{
	const int sx = x0 < x1 ? 1 : -1; // [bp - 2]
	const int sy = y0 < y1 ? 1 : -1; // [bp - 4]

	int dx = abs(x1 - x0); // ax
	int dy = abs(y1 - y0); // bx

	int err = (dx > dy ? dx : -dy) >> 1; // [bp - 6]
	int temp; // [bp - 8]

	for (; ; )
	{
		if (!draw_pixel(x0, y0))
			break;

		if (x0 == x1 && y0 == y1) 
			break;

		temp = err;

		if (temp > -dx)
		{ 
			err -= dy;
			x0 += sx;
		}

		if (temp < dy)
		{
			err += dx;
			y0 += sy; 
		}
	}
}