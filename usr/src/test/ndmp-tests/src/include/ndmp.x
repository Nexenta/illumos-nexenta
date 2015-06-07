#define VER 4
const NDMPVER = VER;
const NDMPPORT = 10000;

		  enum ndmp_header_message_type  
                  { 
                      NDMP_MESSAGE_REQUEST          = 0, 
                      NDMP_MESSAGE_REPLY            = 1 
                  }; 
                   
                  const NDMP_MESSAGE_POST = NDMP_MESSAGE_REQUEST; 
                   
                  struct ndmp_pval 
                  { 
                      string      name<>; 
                      string      value<>; 
                  }; 
                   
                  struct ndmp_u_quad 
                  { 
                      u_long high; 
                      u_long low; 
                  }; 
                   
                   /* Note: because of extensibility, this is */ 
                   /* not a complete list of errors. */ 
                  enum ndmp_error  
                  { 
                      NDMP_NO_ERR                     =  0, 
                      NDMP_NOT_SUPPORTED_ERR          =  1, 
                      NDMP_DEVICE_BUSY_ERR            =  2, 
                      NDMP_DEVICE_OPENED_ERR          =  3, 
                      NDMP_NOT_AUTHORIZED_ERR         =  4, 
                      NDMP_PERMISSION_ERR             =  5, 
                      NDMP_DEV_NOT_OPEN_ERR           =  6, 
                      NDMP_IO_ERR                     =  7,    
                      NDMP_TIMEOUT_ERR                =  8,    
                      NDMP_ILLEGAL_ARGS_ERR           =  9,    
                      NDMP_NO_TAPE_LOADED_ERR         = 10,    
                      NDMP_WRITE_PROTECT_ERR          = 11,    
                      NDMP_EOF_ERR                    = 12,    
                      NDMP_EOM_ERR                    = 13,    
                      NDMP_FILE_NOT_FOUND_ERR         = 14,    
                      NDMP_BAD_FILE_ERR               = 15,    
                      NDMP_NO_DEVICE_ERR              = 16,    
                      NDMP_NO_BUS_ERR                 = 17,    
                      NDMP_XDR_DECODE_ERR             = 18,    
                      NDMP_ILLEGAL_STATE_ERR          = 19,    
                      NDMP_UNDEFINED_ERR              = 20,    
                      NDMP_XDR_ENCODE_ERR             = 21,    
                      NDMP_NO_MEM_ERR                 = 22,    
                      NDMP_CONNECT_ERR                = 23,  
                      NDMP_SEQUENCE_NUM_ERR           = 24,    
                      NDMP_READ_IN_PROGRESS_ERR       = 25, 
                      NDMP_PRECONDITION_ERR           = 26,  
                      NDMP_CLASS_NOT_SUPPORTED_ERR    = 27,
                      NDMP_VERSION_NOT_SUPPORTED_ERR  = 28, 
                      NDMP_EXT_DUPL_CLASSES_ERR       = 29, 
                      NDMP_EXT_DANDN_ILLEGAL_ERR       = 30 
                  }; 
                   
                  /* Note: Because of extensibility, this */ 
                  /* is not a complete list of messages */ 
                  enum ndmp_message  
                  { 
                       
                      NDMP_CONNECT_OPEN               = 0x900, 
                      NDMP_CONNECT_CLIENT_AUTH        = 0x901, 
                      NDMP_CONNECT_CLOSE              = 0x902, 
                      NDMP_CONNECT_SERVER_AUTH        = 0x903, 
                   
                      NDMP_CONFIG_GET_HOST_INFO       = 0x100, 
                      NDMP_CONFIG_GET_CONNECTION_TYPE = 0x102,           
                      NDMP_CONFIG_GET_AUTH_ATTR       = 0x103, 
                      NDMP_CONFIG_GET_BUTYPE_INFO     = 0x104, 
                      NDMP_CONFIG_GET_FS_INFO         = 0x105, 
                      NDMP_CONFIG_GET_TAPE_INFO       = 0x106, 
                      NDMP_CONFIG_GET_SCSI_INFO       = 0x107, 
                      NDMP_CONFIG_GET_SERVER_INFO     = 0x108, 
                      NDMP_CONFIG_SET_EXT_LIST        = 0x109, 
                      NDMP_CONFIG_GET_EXT_LIST        = 0x10A, 
                   
                      NDMP_SCSI_OPEN                  = 0x200,     
                      NDMP_SCSI_CLOSE                 = 0x201, 
                      NDMP_SCSI_GET_STATE             = 0x202, 
                      NDMP_SCSI_RESET_DEVICE          = 0x204, 
                      NDMP_SCSI_EXECUTE_CDB           = 0x206, 
                   
                      NDMP_TAPE_OPEN                  = 0x300, 
                      NDMP_TAPE_CLOSE                 = 0x301, 
                      NDMP_TAPE_GET_STATE             = 0x302, 
                      NDMP_TAPE_MTIO                  = 0x303, 
                      NDMP_TAPE_WRITE                 = 0x304, 
                      NDMP_TAPE_READ                  = 0x305, 
                      NDMP_TAPE_EXECUTE_CDB           = 0x307, 
                   
                      NDMP_DATA_GET_STATE             = 0x400, 
                      NDMP_DATA_START_BACKUP          = 0x401, 
                      NDMP_DATA_START_RECOVER         = 0x402, 
                      NDMP_DATA_ABORT                 = 0x403, 
                      NDMP_DATA_GET_ENV               = 0x404, 
                      NDMP_DATA_STOP                  = 0x407, 
                      NDMP_DATA_LISTEN                = 0x409,  
                      NDMP_DATA_CONNECT               = 0x40A, 
                      NDMP_DATA_START_RECOVER_FILEHIST = 0x40B, 
                   
                      NDMP_NOTIFY_DATA_HALTED         = 0x501,     
                      NDMP_NOTIFY_CONNECTION_STATUS   = 0x502,     
                      NDMP_NOTIFY_MOVER_HALTED        = 0x503, 
                      NDMP_NOTIFY_MOVER_PAUSED        = 0x504, 
                      NDMP_NOTIFY_DATA_READ           = 0x505, 
                   
                      NDMP_LOG_FILE                   = 0x602, 
                      NDMP_LOG_MESSAGE                = 0x603, 
                   
                      NDMP_FH_ADD_FILE                = 0x703, 
                      NDMP_FH_ADD_DIR                 = 0x704, 
                      NDMP_FH_ADD_NODE                = 0x705, 
                   
                      NDMP_MOVER_GET_STATE            = 0xA00, 
                      NDMP_MOVER_LISTEN               = 0xA01, 
                      NDMP_MOVER_CONTINUE             = 0xA02, 
                      NDMP_MOVER_ABORT                = 0xA03, 
                      NDMP_MOVER_STOP                 = 0xA04, 
                      NDMP_MOVER_SET_WINDOW           = 0xA05, 
                      NDMP_MOVER_READ                 = 0xA06, 
                      NDMP_MOVER_CLOSE                = 0xA07, 
                      NDMP_MOVER_SET_RECORD_SIZE      = 0xA08, 
                      NDMP_MOVER_CONNECT              = 0xA09, 
                   
                      NDMP_EXT_STANDARD_BASE          = 0x10000, 
                   
                      NDMP_EXT_PROPRIETARY_BASE       = 0x20000000 
                  }; 
                   
                  struct ndmp_header  
                  { 
                      u_long                    sequence; 
                      u_long                    time_stamp; 
                      ndmp_header_message_type  message_type; 
                      ndmp_message              message_code; 
                      u_long                    reply_sequence; 
                      ndmp_error                error_code; 
                  }; 
                   
                  struct ndmp_connect_open_request  
                  { 
                      u_short     protocol_version; 
                  };  
                   
                  struct ndmp_connect_open_reply  
                  { 
                      ndmp_error  error; 
                  }; 
                   
                  enum ndmp_auth_type  
                  { 
                      NDMP_AUTH_NONE  = 0, 
                      NDMP_AUTH_TEXT  = 1, 
                      NDMP_AUTH_MD5   = 2 
                  };  
                   
                  struct ndmp_auth_text  
                  { 
                      string auth_id<>; 
                      string auth_password<>; 
                  };  
                   
                  struct ndmp_auth_md5  
                  { 
                      string   auth_id<>; 
                      opaque   auth_digest[16]; 
                  };  
                   
                  union ndmp_auth_data  
                      switch (enum ndmp_auth_type   auth_type)  
                  { 
                      case NDMP_AUTH_NONE: 
                          void; 
                      case NDMP_AUTH_TEXT: 
                          struct ndmp_auth_text   auth_text; 
                      case NDMP_AUTH_MD5: 
                          struct ndmp_auth_md5    auth_md5; 
                  };  
                   
                  union ndmp_auth_attr 
                      switch (enum ndmp_auth_type auth_type) 
                  { 
                      case NDMP_AUTH_NONE: 
                          void; 
                      case NDMP_AUTH_TEXT: 
                          void; 
                      case NDMP_AUTH_MD5: 
                          opaque challenge[64]; 
                  }; 
                   
                  struct ndmp_connect_client_auth_request  
                  { 
                      ndmp_auth_data   auth_data; 
                  };  
                   
                  struct ndmp_connect_client_auth_reply  
                  { 
                      ndmp_error       error; 
                  };  
                   
                  struct ndmp_connect_server_auth_request  
                  { 
                      ndmp_auth_attr   client_attr; 
                  };  
                   
                  struct ndmp_connect_server_auth_reply  
                  { 
                      ndmp_error            error; 
                      ndmp_auth_data        server_result; 
                  };  
                   
                  struct ndmp_config_get_host_info_reply  
                  { 
                      ndmp_error  error; 
                      string      hostname<>; 
                      string      os_type<>; 
                      string      os_vers<>; 
                      string      hostid<>; 
                  }; 
                   
                  struct ndmp_config_get_server_info_reply  
                  { 
                      ndmp_error        error; 
                      string            vendor_name<>; 
                      string            product_name<>; 
                      string            revision_number<>; 
                      ndmp_auth_type    auth_type<>; 
                  }; 
                   
                  enum ndmp_addr_type  
                  { 
                      NDMP_ADDR_LOCAL    = 0, 
                      NDMP_ADDR_TCP      = 1, 
                      NDMP_ADDR_RESERVED = 2, 
                      NDMP_ADDR_IPC      = 3 
                  }; 
                   
                  struct ndmp_config_get_connection_type_reply  
                  { 
                      ndmp_error          error; 
                      ndmp_addr_type      addr_types<>; 
                  }; 
                   
                  struct ndmp_config_get_auth_attr_request  
                  { 
                      ndmp_auth_type      auth_type; 
                  };  
                   
                  struct ndmp_config_get_auth_attr_reply  
                  { 
                      ndmp_error          error; 
                      ndmp_auth_attr      server_attr; 
                  }; 
                   
                  const NDMP_BUTYPE_BACKUP_FILELIST        = 0x0002; 
                  const NDMP_BUTYPE_RECOVER_FILELIST       = 0x0004; 
                  const NDMP_BUTYPE_BACKUP_DIRECT          = 0x0008; 
                  const NDMP_BUTYPE_RECOVER_DIRECT         = 0x0010; 
                  const NDMP_BUTYPE_BACKUP_INCREMENTAL     = 0x0020; 
                  const NDMP_BUTYPE_RECOVER_INCREMENTAL    = 0x0040; 
                  const NDMP_BUTYPE_BACKUP_UTF8            = 0x0080; 
                  const NDMP_BUTYPE_RECOVER_UTF8           = 0x0100; 
                  const NDMP_BUTYPE_BACKUP_FH_FILE         = 0x0200; 
                  const NDMP_BUTYPE_BACKUP_FH_DIR          = 0x0400; 
                  const NDMP_BUTYPE_RECOVER_FILEHIST       = 0x0800; 
                  const NDMP_BUTYPE_RECOVER_FH_FILE        = 0x1000; 
                  const NDMP_BUTYPE_RECOVER_FH_DIR         = 0x2000; 
                   
                  struct ndmp_butype_info  
                  { 
                      string      butype_name<>; 
                      ndmp_pval   default_env<>; 
                      u_long      attrs; 
                  };  
                   
                  struct ndmp_config_get_butype_attr_reply  
                  { 
                      ndmp_error            error; 
                      ndmp_butype_info      butype_info<>; 
                  }; 
                   
                  const NDMP_FS_INFO_TOTAL_SIZE_UNS    = 0x00000001; 
                  const NDMP_FS_INFO_USED_SIZE_UNS     = 0x00000002; 
                  const NDMP_FS_INFO_AVAIL_SIZE_UNS    = 0x00000004; 
                  const NDMP_FS_INFO_TOTAL_INODES_UNS  = 0x00000008; 
                  const NDMP_FS_INFO_USED_INODES_UNS   = 0x00000010;  
                   
                  struct ndmp_fs_info  
                  { 
                      u_long            unsupported; 
                      string            fs_type<>; 
                      string            fs_logical_device<>; 
                      string            fs_physical_device<>; 
                      ndmp_u_quad       total_size; 
                      ndmp_u_quad       used_size; 
                      ndmp_u_quad       avail_size; 
                      ndmp_u_quad       total_inodes; 
                      ndmp_u_quad       used_inodes; 
                      ndmp_pval         fs_env<>; 
                      string            fs_status<>; 
                  };  
                   
                  struct ndmp_config_get_fs_info_reply  
                  { 
                      ndmp_error        error; 
                      ndmp_fs_info      fs_info<>; 
                  }; 
                   
                  const NDMP_TAPE_ATTR_REWIND = 0x00000001; 
                  const NDMP_TAPE_ATTR_UNLOAD = 0x00000002; 
                  const NDMP_TAPE_ATTR_RAW    = 0x00000004; 
                    
                  struct ndmp_device_capability  
                  { 
                      string                  device<>; 
                      u_long                  attr; 
                      ndmp_pval               capability<>; 
                  };  
                   
                  struct ndmp_device_info  
                  { 
                      string                  model<>; 
                      ndmp_device_capability  caplist<>; 
                  }; 
                   
                  struct ndmp_config_get_tape_info_reply  
                  { 
                      ndmp_error              error; 
                      ndmp_device_info        tape_info<>; 
                  };  
                   
                  struct ndmp_config_get_scsi_info_reply 
                  { 
                      ndmp_error            error; 
                      ndmp_device_info      scsi_info<>; 
                  }; 
                   
                  struct ndmp_class_list  
                  { 
                      u_short      ext_class_id; 
                      u_short      ext_version<>; 
                  };  
                   
                  struct ndmp_class_version 
                  { 
                      u_short      ext_class_id; 
                      u_short      ext_version; 
                  }; 
                   
                  struct ndmp_config_get_ext_list_reply 
                  { 
                      ndmp_error         error; 
                      ndmp_class_list    class_list<>; 
                  }; 
                   
                  struct ndmp_config_set_ext_list_request 
                  { 
                      ndmp_class_version    ndmp_selected_ext<>; 
                  };  
                   
                  struct ndmp_config_set_ext_list_reply 
                  { 
                      ndmp_error      error; 
                  }; 
                   
                  struct ndmp_scsi_open_request 
                  { 
                       string      device<>; 
                  }; 
                   
                  struct ndmp_scsi_open_reply 
                  { 
                      ndmp_error      error; 
                  }; 
                   
                  struct ndmp_scsi_close_reply 
                  { 
                      ndmp_error      error; 
                  }; 
                   
                  struct ndmp_scsi_get_state_reply 
                  { 
                      ndmp_error       error; 
                      short            target_controller; 
                      short            target_id; 
                      short            target_lun; 
                  }; 
                   
                  struct ndmp_scsi_reset_device_reply 
                  { 
                      ndmp_error      error; 
                  }; 
                   
                  const NDMP_SCSI_DATA_IN  = 0x00000001; 
                  const NDMP_SCSI_DATA_OUT = 0x00000002; 
                   
                  struct ndmp_execute_cdb_request 
                  { 
                      u_long            flags; 
                      u_long            timeout; 
                      u_long            datain_len; 
                      opaque            cdb<>; 
                      opaque            dataout<>; 
                  }; 
                   
                  struct ndmp_execute_cdb_reply 
                  { 
                      ndmp_error        error; 
                      u_char            status; 
                      u_long            dataout_len; 
                      opaque            datain<>; 
                      opaque            ext_sense<>; 
                  }; 

                  enum ndmp_tape_open_mode 
                  { 
                      NDMP_TAPE_READ_MODE = 0, 
                      NDMP_TAPE_RDWR_MODE = 1, 
                      NDMP_TAPE_RAW_MODE  = 2 
                  }; 
                   
                  struct ndmp_tape_open_request  
                  { 
                      string                   device<>; 
                      ndmp_tape_open_mode      mode; 
                  }; 
                   
                  struct ndmp_tape_open_reply  
                  { 
                      ndmp_error      error; 
                  }; 
                   
                  struct ndmp_tape_close_reply 
                  { 
                      ndmp_error      error; 
                  }; 
                   
                  const NDMP_TAPE_STATE_NOREWIND         = 0x0008;  
                  const NDMP_TAPE_STATE_WR_PROT          = 0x0010;  
                  const NDMP_TAPE_STATE_ERROR            = 0x0020;  
                  const NDMP_TAPE_STATE_UNLOAD           = 0x0040;  
                  const NDMP_TAPE_STATE_FILE_NUM_UNS     = 0x00000001; 
                  const NDMP_TAPE_STATE_SOFT_ERRORS_UNS  = 0x00000002; 
                  const NDMP_TAPE_STATE_BLOCK_SIZE_UNS   = 0x00000004; 
                  const NDMP_TAPE_STATE_BLOCKNO_UNS      = 0x00000008; 
                  const NDMP_TAPE_STATE_TOTAL_SPACE_UNS  = 0x00000010; 
                  const NDMP_TAPE_STATE_SPACE_REMAIN_UNS = 0x00000020; 
                  const NDMP_TAPE_STATE_RESERVED1_UNS    = 0x00000040; 
                   
                  struct ndmp_tape_get_state_reply 
                  { 
                      u_long       unsupported; 
                      ndmp_error   error; 
                      u_long       flags; 
                      u_long       file_num; 
                      u_long       soft_errors; 
                      u_long       block_size; 
                      u_long       blockno; 
                      ndmp_u_quad  total_space; 
                      ndmp_u_quad  space_remain; 
                  }; 
                   
                  enum ndmp_tape_mtio_op 
                  { 
                      NDMP_MTIO_FSF  = 0, 
                      NDMP_MTIO_BSF  = 1, 
                      NDMP_MTIO_FSR  = 2, 
                      NDMP_MTIO_BSR  = 3, 
                      NDMP_MTIO_REW  = 4, 
                      NDMP_MTIO_EOF  = 5, 
                      NDMP_MTIO_OFF  = 6, 
                      NDMP_MTIO_TUR  = 7 
                  }; 
                   
                  struct ndmp_tape_mtio_request 
                  { 
                      ndmp_tape_mtio_op   tape_op; 
                      u_long              count; 
                  }; 
                   
                  struct ndmp_tape_mtio_reply 
                  { 
                      ndmp_error          error; 
                      u_long              resid_count; 
                  }; 
                   
                  struct ndmp_tape_write_request 
                  { 
                      opaque              data_out<>; 
                  }; 
                   
                  struct ndmp_tape_write_reply 
                  { 
                      ndmp_error          error; 
                      u_long              count; 
                  }; 
                   
                   
                  struct ndmp_tape_read_request 
                  { 
                      u_long              count; 
                  }; 
                   
                  struct ndmp_tape_read_reply 
                  { 
                      ndmp_error          error; 
                      opaque              data_in<>; 
                  }; 
                   
                  typedef ndmp_execute_cdb_request ndmp_tape_execute_cdb_request; 
                  typedef ndmp_execute_cdb_request ndmp_scsi_execute_cdb_request; 
                  typedef ndmp_execute_cdb_reply ndmp_tape_execute_cdb_reply; 
                  typedef ndmp_execute_cdb_reply ndmp_scsi_execute_cdb_reply; 
                   
                   
                  enum ndmp_data_operation  
                  {  
                      NDMP_DATA_OP_NOACTION           = 0,  
                      NDMP_DATA_OP_BACKUP             = 1,  
                      NDMP_DATA_OP_RECOVER            = 2,  
                      NDMP_DATA_OP_RECOVER_FILEHIST   = 3  
                  }; 
                   
                  enum ndmp_data_state  
                  { 
                      NDMP_DATA_STATE_IDLE      = 0, 
                      NDMP_DATA_STATE_ACTIVE    = 1, 
                      NDMP_DATA_STATE_HALTED    = 2, 
                      NDMP_DATA_STATE_LISTEN    = 3, 
                      NDMP_DATA_STATE_CONNECTED = 4 
                  };  
                   
                  enum ndmp_data_halt_reason  
                  { 
                      NDMP_DATA_HALT_NA             = 0, 
                      NDMP_DATA_HALT_SUCCESSFUL     = 1, 
                      NDMP_DATA_HALT_ABORTED        = 2, 
                      NDMP_DATA_HALT_INTERNAL_ERROR = 3, 
                      NDMP_DATA_HALT_CONNECT_ERROR  = 4 
                  }; 
                   
                   struct ndmp_tcp_addr  
                  { 
                      u_long       ip_addr; 
                      u_short      port; 
                      ndmp_pval    addr_env<>; 
                  }; 
                   
                  struct ndmp_ipc_addr  
                  { 
                      opaque comm_data<>; 
                  };  
                   
                  union ndmp_addr  
                  switch (ndmp_addr_type addr_type)  
                  { 
                      case NDMP_ADDR_LOCAL: 
                          void; 
                      case NDMP_ADDR_TCP: 
                          ndmp_tcp_addr  tcp_addr<>; 
                      case NDMP_ADDR_IPC: 
                          ndmp_ipc_addr  ipc_addr; 
                  };  
                   
                  const NDMP_DATA_STATE_EST_BYTES_REMAIN_UNS = 0x00000001; 
                  const NDMP_DATA_STATE_EST_TIME_REMAIN_UNS  = 0x00000002; 
                   
                  struct ndmp_data_get_state_reply  
                  { 
                      u_long                    unsupported; 
                      ndmp_error                error; 
                      ndmp_data_operation       operation; 
                      ndmp_data_state           state; 
                      ndmp_data_halt_reason     halt_reason; 
                      ndmp_u_quad               bytes_processed; 
                      ndmp_u_quad               est_bytes_remain; 
                      u_long                    est_time_remain; 
                      ndmp_addr                 data_connection_addr; 
                      ndmp_u_quad               read_offset; 
                      ndmp_u_quad               read_length; 
                  }; 
                   
                  struct ndmp_data_listen_request  
                  { 
                      ndmp_addr_type   addr_type; 
                  };  
                   
                  struct ndmp_data_listen_reply  
                  { 
                      ndmp_error   error; 
                      ndmp_addr    connect_addr; 
                  }; 
                   
                  struct ndmp_data_connect_request  
                  { 
                      ndmp_addr   addr; 
                  };  
                   
                  struct ndmp_data_connect_reply  
                  { 
                      ndmp_error   error; 
                  }; 
                   
                  struct ndmp_data_start_backup_request  
                  {  
                      string          butype_name<>;  
                      ndmp_pval       env<>;  
                  }; 
                   
                  struct ndmp_data_start_backup_reply  
                  { 
                      ndmp_error     error; 
                  }; 
                   
                  struct ndmp_name  
                  { 
                      string       original_path<>; 
                      string       destination_dir<>; 
                      string       name<>; 
                      string       other_name<>; 
                      ndmp_u_quad  node; 
                      ndmp_u_quad  fh_info; 
                  };  

                  struct ndmp_data_start_recover_request  
                  {  
                      ndmp_pval       env<>;  
                      ndmp_name       nlist<>;  
                      string          butype_name<>;  
                  };  
                   
                  struct ndmp_data_start_recover_reply  
                  { 
                      ndmp_error      error; 
                  }; 
                   
                  struct ndmp_data_abort_reply  
                  { 
                      ndmp_error error; 
                  }; 
                   
                  struct ndmp_data_stop_reply  
                  { 
                      ndmp_error error; 
                  }; 
                   
                  struct ndmp_data_get_env_reply  
                  { 
                      ndmp_error  error; 
                      ndmp_pval   env<>; 
                  }; 
                   
                  enum ndmp_mover_mode  
                  { 
                      NDMP_MOVER_MODE_READ            = 0,  
                      NDMP_MOVER_MODE_WRITE           = 1,  
                      NDMP_MOVER_MODE_NOACTION        = 2  
                  };  
                   
                  enum ndmp_mover_state 
                  { 
                      NDMP_MOVER_STATE_IDLE    = 0, 
                      NDMP_MOVER_STATE_LISTEN  = 1, 
                      NDMP_MOVER_STATE_ACTIVE  = 2, 
                      NDMP_MOVER_STATE_PAUSED  = 3, 
                      NDMP_MOVER_STATE_HALTED  = 4 
                  }; 
                   
                  enum ndmp_mover_pause_reason 
                  { 
                      NDMP_MOVER_PAUSE_NA    = 0, 
                      NDMP_MOVER_PAUSE_EOM   = 1, 
                      NDMP_MOVER_PAUSE_EOF   = 2, 
                      NDMP_MOVER_PAUSE_SEEK  = 3, 
                      NDMP_MOVER_PAUSE_EOW  = 5 
                  }; 
                   
                  enum ndmp_mover_halt_reason 
                  { 
                      NDMP_MOVER_HALT_NA             = 0, 
                      NDMP_MOVER_HALT_CONNECT_CLOSED = 1, 
                      NDMP_MOVER_HALT_ABORTED        = 2, 
                      NDMP_MOVER_HALT_INTERNAL_ERROR = 3, 
                      NDMP_MOVER_HALT_CONNECT_ERROR  = 4, 
                      NDMP_MOVER_HALT_MEDIA_ERROR    = 5 
                  }; 
                   
                  struct ndmp_mover_set_record_size_request  
                  { 
                      u_long         len;             
                  }; 
                   
                  struct ndmp_mover_set_record_size_reply  
                  { 
                      ndmp_error     error; 
                  }; 
                   
                  struct ndmp_mover_set_window_request  
                  { 
                      ndmp_u_quad            offset; 
                      ndmp_u_quad            length; 
                  }; 
                   
                  struct ndmp_mover_set_window_reply  
                  { 
                      ndmp_error             error; 
                  }; 
                   
                  struct ndmp_mover_connect_request  
                  { 
                      ndmp_mover_mode       mode; 
                      ndmp_addr             addr; 
                  }; 
                   
                  struct ndmp_mover_connect_reply  
                  { 
                      ndmp_error            error; 
                  }; 
                   
                  struct ndmp_mover_listen_request  
                  { 
                      ndmp_mover_mode         mode; 
                      ndmp_addr_type          addr_type; 
                  }; 
                   
                  struct ndmp_mover_listen_reply  
                  { 
                      ndmp_error           error; 
                      ndmp_addr            connect_addr; 
                  }; 
                   
                  struct ndmp_mover_read_request  
                  { 
                      ndmp_u_quad            offset; 
                      ndmp_u_quad            length; 
                  }; 
                   
                  struct ndmp_mover_read_reply  
                  { 
                      ndmp_error            error; 
                  }; 
                   
                  struct ndmp_mover_get_state_reply  
                  {  
                      ndmp_error               error;  
                      ndmp_mover_mode          mode;  
                      ndmp_mover_state         state;  
                      ndmp_mover_pause_reason  pause_reason;  
                      ndmp_mover_halt_reason   halt_reason;  
                      u_long                   record_size;  
                      u_long                   record_num;  
                      ndmp_u_quad              bytes_moved;  
                      ndmp_u_quad              seek_position;  
                      ndmp_u_quad              bytes_left_to_read;  
                      ndmp_u_quad              window_offset;  
                      ndmp_u_quad              window_length;  
                      ndmp_addr                data_connection_addr;  
                  };  
                   
                  struct ndmp_mover_continue_reply  
                  { 
                  ndmp_error            error; 
                  }; 
                   
                  struct ndmp_mover_close_reply  
                  { 
                      ndmp_error            error; 
                  }; 
                   
                  struct ndmp_mover_abort_reply  
                  { 
                      ndmp_error            error; 
                  }; 
                   
                  struct ndmp_mover_stop_reply  
                  { 
                      ndmp_error            error; 
                  }; 
                   
                  struct ndmp_notify_data_halted_post 
                  { 
                      ndmp_data_halt_reason   reason; 
                  }; 
                   
                  enum ndmp_connection_status_reason 
                  { 
                      NDMP_CONNECTED  = 0, 
                      NDMP_SHUTDOWN   = 1, 
                      NDMP_REFUSED    = 2  
                  }; 
                   
                  struct ndmp_notify_connection_status_post 
                  { 
                      ndmp_connection_status_reason       reason; 
                      u_short                             protocol_version; 
                      string                              text_reason<>; 
                  }; 
                   
                  struct ndmp_notify_mover_halted_post 
                  { 
                      ndmp_mover_halt_reason      reason; 
                  }; 
                   
                  struct ndmp_notify_mover_paused_post 
                  { 
                      ndmp_mover_pause_reason reason; 
                      ndmp_u_quad             seek_position; 
                  }; 
                   
                  struct ndmp_notify_data_read_post 
                  { 
                      ndmp_u_quad  offset; 
                      ndmp_u_quad  length; 
                  }; 
                   
                  enum ndmp_has_associated_message 
                  { 
                      NDMP_NO_ASSOCIATED_MESSAGE     = 0, 
                      NDMP_HAS_ASSOCIATED_MESSAGE    = 1 
                  }; 
                   
                  enum ndmp_log_type 
                  { 
                      NDMP_LOG_NORMAL  = 0, 
                      NDMP_LOG_DEBUG   = 1, 
                      NDMP_LOG_ERROR   = 2, 
                      NDMP_LOG_WARNING = 3 
                  }; 
                   
                  struct ndmp_log_message_post 
                  { 
                      ndmp_log_type      log_type; 
                      u_long             message_id; 
                      string             entry<>; 
                      ndmp_has_associated_message associated_message_valid; 
                      u_long             associated_message_sequence; 
                  }; 
                   
                  enum ndmp_recovery_status 
                  { 
                      NDMP_RECOVERY_SUCCESSFUL                 = 0,    
                      NDMP_RECOVERY_FAILED_PERMISSION          = 1, 
                      NDMP_RECOVERY_FAILED_NOT_FOUND           = 2, 
                      NDMP_RECOVERY_FAILED_NO_DIRECTORY        = 3, 
                      NDMP_RECOVERY_FAILED_OUT_OF_MEMORY       = 4, 
                      NDMP_RECOVERY_FAILED_IO_ERROR            = 5, 
                      NDMP_RECOVERY_FAILED_UNDEFINED_ERROR     = 6, 
                      NDMP_RECOVERY_FAILED_FILE_PATH_EXISTS    = 7 
                  }; 
                   
                  struct ndmp_log_file_post 
                  { 
                      string                   name<>; 
                      ndmp_recovery_status     recovery_status; 
                  }; 
                   
                  enum ndmp_fs_type 
                  { 
                      NDMP_FS_UNIX   = 0, 
                      NDMP_FS_NT     = 1, 
                      NDMP_FS_OTHER  = 2 
                  }; 
                   
                  typedef string ndmp_path<>; 
                   
                  struct ndmp_nt_path 
                  { 
                      ndmp_path      nt_path; 
                      ndmp_path      dos_path; 
                  }; 
                   
                  union ndmp_file_name  
                  switch (ndmp_fs_type fs_type) 
                  { 
                      case NDMP_FS_UNIX: 
                          ndmp_path      unix_name; 
                      case NDMP_FS_NT: 
                          ndmp_nt_path   nt_name; 
                      default: 
                          ndmp_path      other_name; 
                  }; 
                   
                  enum ndmp_file_type 
                  { 
                      NDMP_FILE_DIR      = 0, 
                      NDMP_FILE_FIFO     = 1, 
                      NDMP_FILE_CSPEC    = 2, 
                      NDMP_FILE_BSPEC    = 3, 
                      NDMP_FILE_REG      = 4, 
                      NDMP_FILE_SLINK    = 5, 
                      NDMP_FILE_SOCK     = 6, 
                      NDMP_FILE_REGISTRY = 7, 
                      NDMP_FILE_OTHER    = 8 
                  }; 
                   
                  const NDMP_FILE_STAT_ATIME_UNS = 0x00000001; 
                  const NDMP_FILE_STAT_CTIME_UNS = 0x00000002; 
                  const NDMP_FILE_STAT_GROUP_UNS = 0x00000004; 
                   
                  struct ndmp_file_stat 
                  { 
                      u_long            unsupported; 
                      ndmp_fs_type      fs_type; 
                      ndmp_file_type    ftype; 
                      u_long            mtime; 
                      u_long            atime; 
                      u_long            ctime; 
                      u_long            owner; 
                      u_long            group;  
                      u_long            fattr; 
                      ndmp_u_quad       size; 
                      u_long            links; 
                  }; 
                   
                  struct ndmp_file 
                  { 
                      ndmp_file_name      name<>; 
                      ndmp_file_stat      stat<>; 
                      ndmp_u_quad         node; 
                      ndmp_u_quad         fh_info; 
                  }; 
                   
                  struct ndmp_fh_add_file_post 
                  { 
                      ndmp_file            files<>; 
                  }; 
                   
                  struct ndmp_dir 
                  { 
                      ndmp_file_name    name<>; 
                      ndmp_u_quad       node; 
                      ndmp_u_quad       parent; 
                  }; 
                   
                  struct ndmp_fh_add_dir_post 
                  { 
                      ndmp_dir dirs<>; 
                  }; 
                   
                  struct ndmp_node 
                  { 
                      ndmp_file_stat    stats<>; 
                      ndmp_u_quad       node; 
                      ndmp_u_quad       fh_info; 
                  }; 
                   
                  struct ndmp_fh_add_node_post 
                  { 
                      ndmp_node         nodes<>; 
                  }; 
