/*
 * Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * BSD 3 Clause License
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *      - Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *      - Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      - Neither the name of Sun Microsystems, Inc. nor the
 *      names of its contributors may be used to endorse or promote products
 *      derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY SUN MICROSYSTEMS, INC. ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL SUN MICROSYSTEMS, INC. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright 2015 Nexenta Systems, Inc.  All rights reserved.
 */

#include <ndmp.h>
#include <log.h>
#include <stdlib.h>
#include <stdio.h>
#include <ndmp_connect.h>

notify_qrec *queue_element(notify_qrec *, void *, ndmp_message, FILE *);
void print_queue(notify_qrec *);

/*
 * queue_element () method queues up the notification message in the qlist.
 * This method inserts element into the queue if queue is not empty.
 * Args are     :
 * qlist	: Pointer to the notify_qrec queue. If this is NULL this method
 *		  creates a queue and inserts the element. If the queue is not
 *		  NULL then it inserts the element to the end of the list.
 * notify	: Pointer to the notify object to be stored in the list
 * messagecode	: messagecode of the notify object to be stored. This is used
 *		  to index the list.
 * log		: Log file handle
 * Return Value : returns the pointer to the list created or updated list with
 *		  new element.
 */

notify_qrec *
    queue_element(notify_qrec *qlist, void *notify, ndmp_message messagecode,
    FILE *log)
{
	if (qlist == NULL) {
		qlist = (notify_qrec *) malloc(sizeof (notify_qrec));
		qlist->messagecode = messagecode;
		qlist->notify = notify;
		qlist->next = NULL;
		ndmp_dprintf(log, "queue_element :"
		    "notification queue created \n");
	} else {
		notify_qrec *temp = qlist;
		while (temp) {
			if (temp->next == NULL) {
				notify_qrec *new = (notify_qrec *)
				    malloc(sizeof (notify_qrec));
				new->messagecode = messagecode;
				new->notify = notify;
				new->next = NULL;
				temp->next = new;
				ndmp_dprintf(log, "queue_element :"
				    "notification added to existing queue \n");
				return (qlist);
			}
			temp = temp->next;
		}
	}
	return (qlist);
}

/*
 * delete_element () method deletes a perticular object in queue based on the
 * messagecode
 * Args are     :
 * list		: Pointer to pointer pointing to the queue
 * messagecode	: messagecode of the notify object to be deleted
 * log		: Log file handle
 * Return Value : returns SUCCESS(0)- success or E_NOTIFY_NOT_FOUND(10) - error
 */

int
delete_element(notify_qrec **list, ndmp_message messagecode, FILE *log)
{
	notify_qrec *qlist = *list;
	notify_qrec *temp = qlist;
	notify_qrec *temp1 = qlist;
	while (temp) {

		if (temp->messagecode == messagecode) {
			if (temp == qlist) {
				qlist = temp->next;
				free(temp->notify);
				free(temp);
				*list = qlist;
				return (SUCCESS);
			}
			temp1->next = temp->next;
			free(temp->notify);
			free(temp);
			return (SUCCESS);
		}
		temp1 = temp;
		temp = temp->next;
	}
	ndmp_dprintf(log, "notification not found on queue & delete failed\n");
	return (E_NOTIFY_NOT_FOUND);
}

/*
 * delete_queue () method deletes the whole queue
 * Args are     :
 * qlist	: Pointer to pointer pointing to the queue
 * log		: Log file handle
 * Return Value : returns SUCCESS(0)- success or E_NOTIFY_NOT_FOUND(10) - error
 */

int
delete_queue(notify_qrec **qlist, FILE *log)
{
	notify_qrec *ptr = *qlist;
	int ret = 0;
	while (ptr && (ret == 0)) {
		ret = delete_element(&ptr, ptr->messagecode, log);
	}
	*qlist = ptr;
	return (ret);
}

/*
 * print_queue () method prints the elements in the queue
 * Args are     :
 * ptr		: Pointer pointing to the queue
 * Return Value : void
 */

void
print_queue(notify_qrec *ptr)
{
	if (ptr == NULL) {
		printf("Queue is NULL \n");
	}
	printf("Table Elments are \n");
	while (ptr) {
		printf("Element addrs  is %x \n", (int)ptr);
		printf("Messagecode is        :%x \n", ptr->messagecode);
		ptr = ptr->next;
	}
}

/*
 * search_element () method searches a perticular object in queue based on the
 * messagecode
 * Args are     :
 * list_ptr	: Pointer to pointer pointing to the queue
 * messagecode	: messagecode of the notify object to be deleted
 * log		: Log file handle
 * Return Value : returns pointer to the object found or NULL if not found
 */

notify_qrec *
search_element(notify_qrec *list_ptr, ndmp_message messagecode, FILE *log)
{
	notify_qrec *ptr = list_ptr;

	if (ptr == NULL) {
		ndmp_dprintf(log, "Queue is NULL search not possible \n");
	}
	while (ptr) {
		if (ptr->messagecode == messagecode) {
			ndmp_dprintf(log, "%x messagecode found returning "
			    "the ptr to element \n", messagecode);
			return (ptr);
		}
		ptr = ptr->next;
	}
	return (NULL);
}

#ifdef UNIT_TEST_QUEUE

int
main(int argc, char ** argv)
{
	ndmp_notify_connection_status_post *notify_1 =
	    (ndmp_notify_connection_status_post *) malloc
	    (sizeof (ndmp_notify_connection_status_post));
	printf("main (): notify addr is 0x%x", notify_1);
	ndmp_message messagecode[5] =
	{NDMP_NOTIFY_CONNECTION_STATUS, NDMP_NOTIFY_DATA_HALTED,
		NDMP_NOTIFY_MOVER_HALTED, NDMP_NOTIFY_MOVER_PAUSED,
		NDMP_NOTIFY_DATA_READ};
	notify_qrec *qlist = NULL;
	FILE *log;
	log = fopen("log-2.out", "w+");
	int ret = 0;

	qlist = queue_element(qlist, notify_1, messagecode[0], log);
	printf("After insertof 1st element \n");


	ndmp_notify_data_halted_post *notify_2 =
	    (ndmp_notify_data_halted_post *) malloc
	    (sizeof (ndmp_notify_data_halted_post));
	qlist = queue_element(qlist, notify_2, messagecode[1], log);
	printf("After insertof 2nd element \n");

	ndmp_notify_mover_paused_post *notify_3 =
	    (ndmp_notify_mover_paused_post *) malloc
	    (sizeof (ndmp_notify_mover_paused_post));
	qlist = queue_element(qlist, notify_3, messagecode[3], log);
	printf("After inserting third element \n");

	ndmp_notify_data_read_post *notify_4 = (ndmp_notify_data_read_post *)
	    malloc(sizeof (ndmp_notify_data_read_post));
	qlist = queue_element(qlist, notify_4, messagecode[4], log);
	printf("After inserting 4th element \n");
	print_queue(qlist);

	ret = delete_element(&qlist, messagecode[0], log);
	printf("After deleting messagecode[0] = %x and ret val = %d\n",
	    messagecode[0], ret);
	print_queue(qlist);

	ret = delete_element(&qlist, messagecode[4], log);
	printf("After deleting messagecode[4] = %x and ret val = %d\n",
	    messagecode[4], ret);
	print_queue(qlist);

	qlist = queue_element(qlist, notify_4, messagecode[4], log);
	printf("After inserting messagecode[4]= %x \n", messagecode[4]);
	print_queue(qlist);

	ret = delete_element(&qlist, messagecode[3], log);
	printf("After deleting messagecode[3] = %x and ret val = %d\n",
	    messagecode[3], ret);
	print_queue(qlist);

	ret = delete_queue(&qlist, log);
	printf("After deleting entire queue and ret val = %d\n", ret);
	print_queue(qlist);

	return (SUCCESS);
}
#endif
