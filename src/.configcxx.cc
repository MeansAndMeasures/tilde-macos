#include <linux/fs.h>
#include <sys/ioctl.h>

int main(int argc, char *argv[]) {
  int fd;
	ioctl(1, FICLONE, fd);
}
