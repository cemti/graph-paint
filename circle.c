#define symm_pixel()\
	draw_pixel(xc + x, yc + y);\
	draw_pixel(xc - x, yc + y);\
	draw_pixel(xc + x, yc - y);\
	draw_pixel(xc - x, yc - y);\
	draw_pixel(xc + y, yc + x);\
	draw_pixel(xc - y, yc + x);\
	draw_pixel(xc + y, yc - x);\
	draw_pixel(xc - y, yc - x)

// (si, di, ebx)
void circle(const int xc, const int yc, const int r)
{
    int x = 0; // eax
	int y = r; // edx
    int d = 3 - 2 * r; // ecx

    for (; ; )
	{
		symm_pixel();
		
		if (x > y)
			break;
		
		++x;

        if (d > 0)
        {
            --y;
            d += 10 + 4 * (x - y);
        }
        else
            d += 6 + 4 * x;
	}
}