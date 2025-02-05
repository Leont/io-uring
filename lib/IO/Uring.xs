#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <liburing.h>


typedef struct ring {
	struct io_uring uring;
	unsigned cqe_count;
} *IO__Uring;

static struct io_uring_sqe* S_get_sqe(pTHX_ struct ring* ring) {
	struct io_uring_sqe* sqe = io_uring_get_sqe(&ring->uring);

	if (!sqe) {
		io_uring_cq_advance(&ring->uring, ring->cqe_count);
		ring->cqe_count = 0;
		io_uring_submit(&ring->uring);
		sqe = io_uring_get_sqe(&ring->uring);
		if (!sqe)
			Perl_croak(aTHX_ "Could not get SQE");
	}

	return sqe;
}
#define get_sqe(ring) S_get_sqe(aTHX_ ring)

typedef int FileDescriptor;
typedef siginfo_t* Signal__Info;
typedef struct __kernel_timespec* Time__Spec;

#undef SvPV
#define SvPV(sv, len) SvPVbyte(sv, len)
#undef SvPV_nolen
#define SvPV_nolen(sv) SvPVbyte_nolen(sv)

MODULE = IO::Uring				PACKAGE = IO::Uring

PROTOTYPES: DISABLED

IO::Uring new(class, UV entries)
CODE:
	RETVAL = safecalloc(1, sizeof(struct ring));
	RETVAL->cqe_count = 0;
	struct io_uring_params params = {};
	params.flags = IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_COOP_TASKRUN | IORING_SETUP_DEFER_TASKRUN;
	io_uring_queue_init_params(entries, &RETVAL->uring, &params);
OUTPUT:
	RETVAL


void DESTROY(IO::Uring self)
	CODE:
	io_uring_queue_exit(&self->uring);
	safefree(self);


void run_once(IO::Uring self, unsigned min_events = 1)
	PPCODE:
	io_uring_submit_and_wait(&self->uring, min_events);

	struct io_uring_cqe *cqe;
	unsigned head;

	EXTEND(SP, 2);
	io_uring_for_each_cqe(&self->uring, head, cqe) {
		++self->cqe_count;
		SV* callback = (SV*)io_uring_cqe_get_data(cqe);
		if (callback) {
			PUSHMARK(SP);
			mPUSHi(cqe->res);
			mPUSHu(cqe->flags);
			PUTBACK;
			call_sv(callback,  G_VOID | G_DISCARD | G_EVAL);
			if (!(cqe->flags & IORING_CQE_F_MORE))
				SvREFCNT_dec(callback);

			if (SvTRUE(ERRSV)) {
				io_uring_cq_advance(&self->uring, self->cqe_count);
				self->cqe_count = 0;
				Perl_croak(aTHX_ NULL);
			}

			SPAGAIN;
		}
	}

	io_uring_cq_advance(&self->uring, self->cqe_count);
	self->cqe_count = 0;


UV accept(IO::Uring self, FileDescriptor fd, UV iflags, SV* callback)
CODE:
	struct io_uring_sqe* sqe = get_sqe(self);
	io_uring_prep_accept(sqe, fd, NULL, NULL, SOCK_CLOEXEC);
	io_uring_sqe_set_flags(sqe, iflags);
	io_uring_sqe_set_data(sqe, SvREFCNT_inc(callback));
	RETVAL = PTR2UV(callback);
OUTPUT:
	RETVAL


UV cancel(IO::Uring self, UV user_data, UV flags, UV iflags, SV* callback = &PL_sv_undef)
CODE:
	struct io_uring_sqe* sqe = get_sqe(self);
	io_uring_prep_cancel(sqe, NUM2PTR(void*, user_data), flags);
	io_uring_sqe_set_flags(sqe, iflags);
	void* cancel_data = SvOK(callback) ? SvREFCNT_inc(callback) : NULL;
	io_uring_sqe_set_data(sqe, cancel_data);
	RETVAL = PTR2UV(cancel_data);
OUTPUT:
	RETVAL


UV connect(IO::Uring self, FileDescriptor fd, const char* sockaddr, size_t length(sockaddr), UV iflags, SV* callback)
CODE:
	struct io_uring_sqe* sqe = get_sqe(self);
	io_uring_prep_connect(sqe, fd, (struct sockaddr*)sockaddr, STRLEN_length_of_sockaddr);
	io_uring_sqe_set_flags(sqe, iflags);
	io_uring_sqe_set_data(sqe, SvREFCNT_inc(callback));
	RETVAL = PTR2UV(callback);
OUTPUT:
	RETVAL


UV read(IO::Uring self, FileDescriptor fd, char* buffer, size_t length(buffer), UV offset, UV iflags, SV* callback)
CODE:
	struct io_uring_sqe* sqe = get_sqe(self);
	io_uring_prep_read(sqe, fd, buffer, STRLEN_length_of_buffer, offset);
	io_uring_sqe_set_flags(sqe, iflags);
	io_uring_sqe_set_data(sqe, SvREFCNT_inc(callback));
	RETVAL = PTR2UV(callback);
OUTPUT:
	RETVAL

UV recv(IO::Uring self, FileDescriptor fd, char* buffer, size_t length(buffer), IV rflags, UV iflags, SV* callback)
CODE:
	struct io_uring_sqe* sqe = get_sqe(self);
	io_uring_prep_recv(sqe, fd, buffer, STRLEN_length_of_buffer, rflags);
	io_uring_sqe_set_flags(sqe, iflags);
	io_uring_sqe_set_data(sqe, SvREFCNT_inc(callback));
	RETVAL = PTR2UV(callback);
OUTPUT:
	RETVAL


UV send(IO::Uring self, FileDescriptor fd, char* buffer, size_t length(buffer), IV sflags, UV iflags, SV* callback)
CODE:
	struct io_uring_sqe* sqe = get_sqe(self);
	io_uring_prep_send(sqe, fd, buffer, STRLEN_length_of_buffer, sflags);
	io_uring_sqe_set_flags(sqe, iflags);
	io_uring_sqe_set_data(sqe, SvREFCNT_inc(callback));
	RETVAL = PTR2UV(callback);
OUTPUT:
	RETVAL

UV timeout(IO::Uring self, Time::Spec ts, UV count, UV flags, UV iflags, SV* callback)
CODE:
	struct io_uring_sqe* sqe = get_sqe(self);
	io_uring_prep_timeout(sqe, ts, count, flags);
	io_uring_sqe_set_flags(sqe, iflags);
	io_uring_sqe_set_data(sqe, SvREFCNT_inc(callback));
	RETVAL = PTR2UV(callback);
OUTPUT:
	RETVAL

UV waitid(IO::Uring self, IV idtype, IV id, Signal::Info info, IV options, UV flags, UV iflags, SV* callback)
CODE:
	struct io_uring_sqe* sqe = get_sqe(self);
	io_uring_prep_waitid(sqe, idtype, id, info, options, flags);
	io_uring_sqe_set_flags(sqe, iflags);
	io_uring_sqe_set_data(sqe, SvREFCNT_inc(callback));
	RETVAL = PTR2UV(callback);
OUTPUT:
	RETVAL


UV write(IO::Uring self, FileDescriptor fd, char* buffer, size_t length(buffer), UV offset, UV iflags, SV* callback)
CODE:
	struct io_uring_sqe* sqe = get_sqe(self);
	io_uring_prep_write(sqe, fd, buffer, STRLEN_length_of_buffer, offset);
	io_uring_sqe_set_flags(sqe, iflags);
	io_uring_sqe_set_data(sqe, SvREFCNT_inc(callback));
	RETVAL = PTR2UV(callback);
OUTPUT:
	RETVAL
