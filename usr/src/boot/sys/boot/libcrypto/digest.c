
#include <sys/cdefs.h>
#include <stdbool.h>
#include <stand.h>
#include <sys/sha1.h>

#include <bootstrap.h>

bool
sha1(vm_offset_t data, size_t size, uint8_t *result)
{
	SHA1_CTX sha1_ctx;
	size_t n, bufsz = 1024;	/* arbitrary buffer size */
	void *buf;

	if (size < bufsz)
		bufsz = size;

	buf = malloc(bufsz);
	if (buf == NULL)
		return (false);

	SHA1Init(&sha1_ctx);
	while (size > 0) {
		n = archsw.arch_copyout(data, buf, bufsz);
		SHA1Update(&sha1_ctx, buf, n);
		data += n;
		size -= n;
		if (size < bufsz)
			bufsz = size;
	}
	SHA1Final(result, &sha1_ctx);
	free(buf);
	return (true);
}

static int
command_sha1(int argc, char **argv)
{
	vm_offset_t ptr;
	size_t size, i;
	uint8_t resultbuf[SHA1_DIGEST_LENGTH];

	/*
	 * usage: address size
	 */
	ptr = (vm_offset_t)strtol(argv[1], NULL, 0);
	size = strtol(argv[2], NULL, 0);

	if (sha1(ptr, size, resultbuf) == false)
		return (CMD_OK);

	for (i = 0; i < SHA1_DIGEST_LENGTH; i++)
		printf("%02x", resultbuf[i]);
	printf("\n");
	return (CMD_OK);
}

COMMAND_SET(sha1, "sha1", "print the sha1 checksum", command_sha1);
